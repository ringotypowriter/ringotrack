import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ringotrack/domain/app_database.dart';
import 'package:ringotrack/domain/demo_mode_controller.dart';
import 'package:ringotrack/domain/demo_usage_repository.dart';
import 'package:ringotrack/domain/drawing_app_preferences.dart';
import 'package:ringotrack/domain/drawing_app_preferences_controller.dart';
import 'package:ringotrack/domain/dashboard_preferences.dart';
import 'package:ringotrack/domain/dashboard_preferences_controller.dart';
import 'package:ringotrack/domain/theme_controller.dart';
import 'package:ringotrack/domain/usage_repository.dart';
import 'package:ringotrack/domain/usage_service.dart';
import 'package:ringotrack/platform/foreground_app_tracker.dart';
import 'package:ringotrack/platform/stroke_activity_tracker.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final demoModeControllerProvider = NotifierProvider<DemoModeController, bool>(
  DemoModeController.new,
);

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

final foregroundAppTrackerProvider = Provider<ForegroundAppTracker>((ref) {
  return createForegroundAppTracker();
});

final strokeActivityTrackerProvider = Provider<StrokeActivityTracker>((ref) {
  final tracker = createStrokeActivityTracker();
  ref.onDispose(tracker.dispose);
  return tracker;
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

// 主题
final appThemeProvider = appThemeControllerProvider;

// Dashboard 偏好（热力图时间范围）
final dashboardPrefsProvider = dashboardPreferencesControllerProvider;

/// 是否使用毛玻璃效果（macOS / Windows 且用户启用时为 true）
final useGlassEffectProvider = Provider<bool>((ref) {
  final prefsAsync = ref.watch(dashboardPreferencesControllerProvider);
  final prefs = prefsAsync.value ?? const DashboardPreferences();
  return prefs.useGlassEffect;
});

/// 根据偏好计算当前热力图的时间窗口。
/// - calendarYear: 当年 1/1 ~ 12/31
/// - rolling12Months: 最近 12 个月，右侧对齐当前月
final heatmapRangeProvider = Provider<({DateTime start, DateTime end})>((ref) {
  final prefsAsync = ref.watch(dashboardPreferencesControllerProvider);
  final mode =
      prefsAsync.value?.heatmapRangeMode ??
      const DashboardPreferences().heatmapRangeMode;

  final today = DateTime.now();
  final normalizedToday = _normalizeDay(today);

  DateTime start;
  DateTime end;

  if (mode == HeatmapRangeMode.rolling12Months) {
    end = DateTime(normalizedToday.year, normalizedToday.month + 1, 0);
    start = DateTime(end.year, end.month - 11, 1);
  } else {
    start = DateTime(normalizedToday.year, 1, 1);
    end = DateTime(normalizedToday.year, 12, 31);
  }

  start = _normalizeDay(start);
  end = _normalizeDay(end);
  return (start: start, end: end);
});

/// 最近一年的使用数据（按日期 -> AppId -> Duration），带实时增量刷新
final yearlyUsageByDateProvider =
    StreamProvider<Map<DateTime, Map<String, Duration>>>((ref) async* {
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
    });

/// 仪表盘指标：今日 / 本周 / 本月 / 连续天数 + 数据更新时间
final dashboardMetricsProvider = Provider<AsyncValue<DashboardMetrics>>((ref) {
  final usageAsync = ref.watch(yearlyUsageByDateProvider);

  return usageAsync.whenData((usageByDate) {
    final today = _normalizeDay(DateTime.now());
    final weekStart = _startOfWeekSundayFirst(today);
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

DateTime _startOfWeekSundayFirst(DateTime date) {
  final normalized = _normalizeDay(date);
  final weekday = normalized.weekday % 7; // 周日 = 0
  return normalized.subtract(Duration(days: weekday));
}

DateTime _normalizeDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
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
