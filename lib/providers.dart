import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ringotrack/domain/app_database.dart';
import 'package:ringotrack/domain/drawing_app_preferences.dart';
import 'package:ringotrack/domain/drawing_app_preferences_controller.dart';
import 'package:ringotrack/domain/theme_controller.dart';
import 'package:ringotrack/domain/usage_repository.dart';
import 'package:ringotrack/domain/usage_service.dart';
import 'package:ringotrack/platform/foreground_app_tracker.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteUsageRepository(db);
});

final foregroundAppTrackerProvider = Provider<ForegroundAppTracker>((ref) {
  return createForegroundAppTracker();
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
  final filter = ref.watch(drawingAppFilterProvider);

  final service = UsageService(
    isDrawingApp: filter,
    repository: repo,
    tracker: tracker,
  );

  ref.onDispose(() {
    service.close();
  });

  return service;
});

// 主题
final appThemeProvider = appThemeControllerProvider;

/// 最近一年的使用数据（按日期 -> AppId -> Duration），带实时增量刷新
final yearlyUsageByDateProvider =
    StreamProvider<Map<DateTime, Map<String, Duration>>>((ref) async* {
      // 确保 UsageService 已启动
      final service = ref.watch(usageServiceProvider);
      final repo = ref.watch(usageRepositoryProvider);

      final today = DateTime.now();
      final start = DateTime(today.year, 1, 1);
      final end = DateTime(today.year, 12, 31);

      // 初始全量
      final usageByDate = await repo.loadRange(start, end);
      yield usageByDate;

      // 后续增量：使用 UsageService.deltaStream 做增量合并
      await for (final delta in service.deltaStream) {
        if (delta.isEmpty) continue;

        delta.forEach((day, perApp) {
          final existingPerApp = usageByDate.putIfAbsent(
            day,
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
  var streak = 0;
  var cursor = today;

  while (true) {
    final dayKey = _normalizeDay(cursor);
    final perApp = usageByDate[dayKey];
    final hasUsage =
        perApp != null &&
        perApp.values.any((duration) => duration > Duration.zero);

    if (!hasUsage) {
      break;
    }

    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return streak;
}
