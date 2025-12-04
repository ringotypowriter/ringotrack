import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ringotrack/domain/app_database.dart';
import 'package:ringotrack/domain/drawing_app_preferences.dart';
import 'package:ringotrack/domain/drawing_app_preferences_controller.dart';
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
  final prefs = prefsAsync.value ??
      const DrawingAppPreferences(trackedAppIds: defaultTrackedAppIds);

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
