import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ringotrack/feature/update/github_release_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringotrack/feature/database/services/app_database.dart';
import 'package:ringotrack/feature/settings/demo/controllers/demo_mode_controller.dart';
import 'package:ringotrack/feature/usage/repositories/demo_usage_repository.dart';
import 'package:ringotrack/feature/settings/drawing_app/models/drawing_app_preferences.dart';
import 'package:ringotrack/feature/settings/drawing_app/controllers/drawing_app_preferences_controller.dart';
import 'package:ringotrack/feature/dashboard/providers/dashboard_providers.dart'
    as dashboard_providers;
import 'package:ringotrack/feature/dashboard/models/dashboard_preferences.dart';
import 'package:ringotrack/feature/settings/theme/controllers/theme_controller.dart';

import 'package:ringotrack/feature/usage/repositories/usage_repository.dart';
import 'package:ringotrack/feature/usage/services/usage_service.dart';
import 'package:ringotrack/platform/foreground_app_tracker.dart';
import 'package:ringotrack/platform/stroke_activity_tracker.dart';

// ============================================================================
// Core Infrastructure Providers
// ============================================================================

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final foregroundAppTrackerProvider = Provider<ForegroundAppTracker>((ref) {
  final tracker = createForegroundAppTracker();
  ref.onDispose(tracker.dispose);
  return tracker;
});

final strokeActivityTrackerProvider = Provider<StrokeActivityTracker>((ref) {
  final tracker = createStrokeActivityTracker();
  ref.onDispose(tracker.dispose);
  return tracker;
});

/// 应用版本信息
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

// ============================================================================
// Settings Providers
// ============================================================================

final demoModeControllerProvider = NotifierProvider<DemoModeController, bool>(
  DemoModeController.new,
);

// drawingAppPrefsControllerProvider is defined in drawing_app_preferences_controller.dart

// Theme controller is defined in theme_controller.dart

// ============================================================================
// Theme Providers (imported from theme_controller.dart)
// ============================================================================

final appThemeProvider = appThemeControllerProvider;

// ============================================================================
// Dashboard Providers (imported from dashboard_providers.dart)
// ============================================================================

final dashboardPreferencesControllerProvider =
    dashboard_providers.dashboardPreferencesControllerProvider;
final windowsGlassEffectDisplayProvider =
    dashboard_providers.windowsGlassEffectDisplayProvider;

// ============================================================================
// Usage Providers
// ============================================================================

final demoUsageRepositoryProvider = Provider.autoDispose<DemoUsageRepository>((
  ref,
) {
  return DemoUsageRepository();
});

final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  final useDemoMode = ref.watch(demoModeControllerProvider);
  if (useDemoMode) {
    return ref.watch(demoUsageRepositoryProvider);
  }
  final db = ref.watch(appDatabaseProvider);
  return SqliteUsageRepository(db);
});

final drawingAppFilterProvider = Provider<bool Function(String)>((ref) {
  final prefsAsync = ref.watch(drawingAppPrefsControllerProvider);
  final prefs =
      prefsAsync.value ??
      const DrawingAppPreferences(trackedApps: defaultTrackedApps);
  return buildAppFilter(prefs);
});

final usageServiceProvider = Provider<UsageService>((ref) {
  final repo = ref.watch(usageRepositoryProvider);
  final tracker = ref.watch(foregroundAppTrackerProvider);
  final strokeTracker = ref.watch(strokeActivityTrackerProvider);
  final filter = ref.watch(drawingAppFilterProvider);

  final service = UsageService(
    isDrawingApp: filter,
    repository: repo,
    tracker: tracker,
    strokeTracker: strokeTracker,
  );

  ref.onDispose(() {
    service.close();
  });

  return service;
});

// ============================================================================
// Dashboard Computed Providers
// ============================================================================

/// 关注本周起点，供热力图/指标使用。
final dashboardWeekStartModeProvider = Provider<WeekStartMode>((ref) {
  final prefsAsync = ref.watch(dashboardPreferencesControllerProvider);
  return prefsAsync.value?.weekStartMode ??
      const DashboardPreferences().weekStartMode;
});

/// 是否使用毛玻璃效果（macOS / Windows 且用户启用时为 true）
final useGlassEffectProvider = Provider<bool>((ref) {
  final prefsAsync = ref.watch(dashboardPreferencesControllerProvider);
  final prefs = prefsAsync.value ?? const DashboardPreferences();
  return prefs.useGlassEffect;
});

/// 根据偏好计算当前热力图的时间窗口。
/// - calendarYear: 当年 1/1 ~ 12/31
/// - rolling12Months: 以焦点月份为结束点的 12 个月窗口
final heatmapRangeProvider = Provider<({DateTime start, DateTime end})>((ref) {
  final prefsAsync = ref.watch(dashboardPreferencesControllerProvider);
  final mode =
      prefsAsync.value?.heatmapRangeMode ??
      const DashboardPreferences().heatmapRangeMode;

  final today = DateTime.now();

  DateTime start;
  DateTime end;

  if (mode == HeatmapRangeMode.rolling12Months) {
    // 使用焦点月份，默认当前月份
    final focusMonth =
        prefsAsync.value?.focusMonth ?? DateTime(today.year, today.month, 1);
    // 以焦点月份为结束点，往前推11个月
    end = DateTime(focusMonth.year, focusMonth.month + 1, 0);
    start = DateTime(end.year, end.month - 11, 1);
  } else {
    final selectedYear = prefsAsync.value?.selectedYear ?? today.year;
    start = DateTime(selectedYear, 1, 1);
    end = DateTime(selectedYear, 12, 31);
  }

  start = _normalizeDay(start);
  end = _normalizeDay(end);
  return (start: start, end: end);
});

/// Summary 指标固定使用当年数据，不随年份切换
final metricsRangeProvider = Provider<({DateTime start, DateTime end})>((ref) {
  final today = DateTime.now();
  final start = _normalizeDay(DateTime(today.year, 1, 1));
  final end = _normalizeDay(DateTime(today.year, 12, 31));
  return (start: start, end: end);
});

/// 最近一年的使用数据（按日期 -> AppId -> Duration），带实时增量刷新
final yearlyUsageByDateProvider =
    StreamProvider.autoDispose<Map<DateTime, Map<String, Duration>>>((
      ref,
    ) async* {
      // 确保 UsageService 已启动
      final service = ref.watch(usageServiceProvider);
      final repo = ref.watch(usageRepositoryProvider);
      final range = ref.watch(heatmapRangeProvider);
      final start = range.start;
      final end = range.end;

      // 初始全量
      final usageByDate = await repo.loadRange(start, end);
      yield usageByDate;

      // 后续增量：使用 UsageService.deltaStream 做增量合并
      try {
        await for (final delta in service.deltaStream) {
          if (delta.isEmpty) continue;

          delta.forEach((day, perApp) {
            final normalizedDay = _normalizeDay(day);
            if (normalizedDay.isBefore(start) || normalizedDay.isAfter(end)) {
              return;
            }

            final existingPerApp = usageByDate.putIfAbsent(
              normalizedDay,
              () => <String, Duration>{},
            );

            perApp.forEach((appId, duration) {
              existingPerApp[appId] =
                  (existingPerApp[appId] ?? Duration.zero) + duration;
            });
          });

          yield Map<DateTime, Map<String, Duration>>.fromEntries(
            usageByDate.entries.map(
              (e) => MapEntry(e.key, Map<String, Duration>.from(e.value)),
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[yearlyUsageByDateProvider] stream closed: $e');
        }
      }
    });

/// 当年使用数据（供 Summary 指标），不受年份选择器影响
final currentYearUsageByDateProvider =
    StreamProvider.autoDispose<Map<DateTime, Map<String, Duration>>>((
      ref,
    ) async* {
      final service = ref.watch(usageServiceProvider);
      final repo = ref.watch(usageRepositoryProvider);
      final range = ref.watch(metricsRangeProvider);
      final start = range.start;
      final end = range.end;

      final usageByDate = await repo.loadRange(start, end);
      yield usageByDate;

      try {
        await for (final delta in service.deltaStream) {
          if (delta.isEmpty) continue;

          delta.forEach((day, perApp) {
            final normalizedDay = _normalizeDay(day);
            if (normalizedDay.isBefore(start) || normalizedDay.isAfter(end)) {
              return;
            }

            final existingPerApp = usageByDate.putIfAbsent(
              normalizedDay,
              () => <String, Duration>{},
            );

            perApp.forEach((appId, duration) {
              existingPerApp[appId] =
                  (existingPerApp[appId] ?? Duration.zero) + duration;
            });
          });

          yield Map<DateTime, Map<String, Duration>>.fromEntries(
            usageByDate.entries.map(
              (e) => MapEntry(e.key, Map<String, Duration>.from(e.value)),
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[currentYearUsageByDateProvider] stream closed: $e');
        }
      }
    });

/// 仪表盘指标：今日 / 本周 / 本月 / 连续天数 + 数据更新时间
final dashboardMetricsProvider = Provider<AsyncValue<DashboardMetrics>>((ref) {
  final usageAsync = ref.watch(currentYearUsageByDateProvider);
  final weekStartMode = ref.watch(dashboardWeekStartModeProvider);

  return usageAsync.whenData((usageByDate) {
    final today = _normalizeDay(DateTime.now());
    final weekStart = startOfWeek(today, weekStartMode);
    final monthStart = DateTime(today.year, today.month, 1);

    var todayTotal = Duration.zero;
    var weekTotal = Duration.zero;
    var monthTotal = Duration.zero;

    usageByDate.forEach((day, perApp) {
      final normalizedDay = _normalizeDay(day);
      final totalForDay = perApp.values.fold(Duration.zero, (a, b) => a + b);

      if (normalizedDay == today) {
        todayTotal += totalForDay;
      }
      if (!normalizedDay.isBefore(weekStart) && !normalizedDay.isAfter(today)) {
        weekTotal += totalForDay;
      }
      if (normalizedDay.year == today.year &&
          normalizedDay.month == today.month &&
          !normalizedDay.isAfter(today) &&
          !normalizedDay.isBefore(monthStart)) {
        monthTotal += totalForDay;
      }
    });

    final streakDays = _calculateCurrentStreak(usageByDate, today);

    return DashboardMetrics(
      today: todayTotal,
      thisWeek: weekTotal,
      thisMonth: monthTotal,
      streakDays: streakDays,
      lastUpdatedAt: DateTime.now(),
    );
  });
});

// ============================================================================
// Update Providers
// ============================================================================

/// GitHub release update check provider
/// Returns the latest version if an update is available, null otherwise
final githubReleaseProvider = FutureProvider<Version?>((ref) async {
  final packageInfo = await ref.watch(packageInfoProvider.future);

  // Parse current app version
  final currentVersionString =
      '${packageInfo.version}+${packageInfo.buildNumber}';
  debugPrint(
    '[GitHubReleaseProvider] Raw version string: $currentVersionString',
  );

  final currentVersion = Version.parse(currentVersionString);
  debugPrint(
    '[GitHubReleaseProvider] Parsed current version: ${currentVersion?.toString() ?? 'null'}',
  );

  if (currentVersion == null) {
    // If we can't parse our own version, don't check for updates
    debugPrint(
      '[GitHubReleaseProvider] Failed to parse current version, skipping update check',
    );
    return null;
  }

  // Get shared preferences for caching
  final prefs = await SharedPreferences.getInstance();

  // Create service and check for updates (normal check with caching)
  final service = GitHubReleaseService();
  final result = await service.checkForUpdates(currentVersion, prefs);
  debugPrint(
    '[GitHubReleaseProvider] Update check result: ${result?.toString() ?? 'null'}',
  );
  return result;
});

/// Manual update check controller
class ManualUpdateCheckController extends Notifier<AsyncValue<Version?>> {
  @override
  AsyncValue<Version?> build() {
    // Start with no data - don't check automatically
    return const AsyncValue.data(null);
  }

  Future<void> checkForUpdates() async {
    state = const AsyncValue.loading();

    try {
      final packageInfo = await PackageInfo.fromPlatform();

      // Parse current app version
      final currentVersionString =
          '${packageInfo.version}+${packageInfo.buildNumber}';
      debugPrint(
        '[ManualUpdateCheck] Raw version string: $currentVersionString',
      );

      final currentVersion = Version.parse(currentVersionString);
      debugPrint(
        '[ManualUpdateCheck] Parsed current version: ${currentVersion?.toString() ?? 'null'}',
      );

      if (currentVersion == null) {
        debugPrint('[ManualUpdateCheck] Failed to parse current version');
        state = const AsyncValue.data(null);
        return;
      }

      // Get shared preferences for caching
      final prefs = await SharedPreferences.getInstance();

      // Create service and check for updates (force check, bypass cache)
      final service = GitHubReleaseService();
      final result = await service.checkForUpdates(
        currentVersion,
        prefs,
        forceCheck: true,
      );
      debugPrint(
        '[ManualUpdateCheck] Manual update check result: ${result?.toString() ?? 'null'}',
      );

      state = AsyncValue.data(result);
    } catch (error, stackTrace) {
      debugPrint('[ManualUpdateCheck] Error: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

/// Manual update check provider
/// Only checks when user explicitly triggers it
final manualUpdateCheckProvider =
    NotifierProvider<ManualUpdateCheckController, AsyncValue<Version?>>(
      ManualUpdateCheckController.new,
    );

// ============================================================================
// Helper Classes and Functions
// ============================================================================

class DashboardMetrics {
  DashboardMetrics({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.streakDays,
    required this.lastUpdatedAt,
  });

  final Duration today;
  final Duration thisWeek;
  final Duration thisMonth;
  final int streakDays;
  final DateTime lastUpdatedAt;
}

DateTime _normalizeDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime startOfWeek(DateTime date, WeekStartMode mode) {
  final normalized = _normalizeDay(date);
  if (mode == WeekStartMode.monday) {
    final offset = (normalized.weekday - DateTime.monday) % 7;
    return normalized.subtract(Duration(days: offset));
  }
  final weekday = normalized.weekday % 7; // 周日 = 0
  return normalized.subtract(Duration(days: weekday));
}

int _calculateCurrentStreak(
  Map<DateTime, Map<String, Duration>> usageByDate,
  DateTime today,
) {
  bool hasUsageOn(DateTime day) {
    final dayKey = _normalizeDay(day);
    final perApp = usageByDate[dayKey];
    return perApp != null &&
        perApp.values.any((duration) => duration > Duration.zero);
  }

  final normalizedToday = _normalizeDay(today);

  // 允许「昨天有画、今天还没画」这种情况继续显示连续天数：
  // - 如果今天有使用记录，从今天往前算；
  // - 否则如果昨天有使用记录，从昨天往前算；
  // - 否则认为当前没有进行中的连续天数（返回 0）。
  DateTime? anchor;
  if (hasUsageOn(normalizedToday)) {
    anchor = normalizedToday;
  } else {
    final yesterday = normalizedToday.subtract(const Duration(days: 1));
    if (hasUsageOn(yesterday)) {
      anchor = yesterday;
    } else {
      return 0;
    }
  }

  var streak = 0;
  var cursor = anchor;

  while (hasUsageOn(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return streak;
}
