import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/domain/usage_models.dart';
import 'package:ringotrack/domain/usage_repository.dart';
import 'package:ringotrack/domain/usage_service.dart';
import 'package:ringotrack/platform/foreground_app_tracker.dart';
import 'package:ringotrack/platform/stroke_activity_tracker.dart';

class _FakeUsageRepository implements UsageRepository {
  final Map<DateTime, Map<String, Duration>> dailyMerged = {};
  final Map<DateTime, Map<int, Map<String, Duration>>> hourlyMerged = {};

  @override
  Future<Map<DateTime, Map<String, Duration>>> loadRange(
    DateTime start,
    DateTime end,
  ) async {
    return {};
  }

  @override
  Future<void> mergeUsage(Map<DateTime, Map<String, Duration>> delta) async {
    delta.forEach((day, perApp) {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      final existingPerApp = dailyMerged.putIfAbsent(
        normalizedDay,
        () => <String, Duration>{},
      );
      perApp.forEach((appId, duration) {
        existingPerApp[appId] =
            (existingPerApp[appId] ?? Duration.zero) + duration;
      });
    });
  }

  @override
  Future<Map<DateTime, Map<int, Map<String, Duration>>>> loadHourlyRange(
    DateTime start,
    DateTime end,
  ) async {
    return {};
  }

  @override
  Future<void> mergeHourlyUsage(
    Map<DateTime, Map<int, Map<String, Duration>>> delta,
  ) async {
    delta.forEach((day, perHour) {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      final existingPerHour = hourlyMerged.putIfAbsent(
        normalizedDay,
        () => <int, Map<String, Duration>>{},
      );

      perHour.forEach((hourIndex, perApp) {
        final existingPerApp = existingPerHour.putIfAbsent(
          hourIndex,
          () => <String, Duration>{},
        );
        perApp.forEach((appId, duration) {
          existingPerApp[appId] =
              (existingPerApp[appId] ?? Duration.zero) + duration;
        });
      });
    });
  }

  @override
  Future<void> deleteByAppId(String appId) async {}

  @override
  Future<void> deleteByDateRange(DateTime start, DateTime end) async {}

  @override
  Future<void> clearAll() async {}
}

class _TestForegroundAppTracker implements ForegroundAppTracker {
  final _controller = StreamController<ForegroundAppEvent>.broadcast(
    sync: true,
  );

  @override
  Stream<ForegroundAppEvent> get events => _controller.stream;

  void emit(ForegroundAppEvent event) {
    _controller.add(event);
  }

  @override
  void dispose() {
    unawaited(_controller.close());
  }
}

class _TestStrokeActivityTracker implements StrokeActivityTracker {
  @override
  Stream<StrokeEvent> get strokes => const Stream<StrokeEvent>.empty();

  @override
  void dispose() {}
}

void main() {
  test('UsageService writes daily and hourly usage to repository', () async {
    final tracker = _TestForegroundAppTracker();
    final strokeTracker = _TestStrokeActivityTracker();
    final repo = _FakeUsageRepository();

    final service = UsageService(
      isDrawingApp: (id) => id == 'Photoshop.exe',
      repository: repo,
      tracker: tracker,
      strokeTracker: strokeTracker,
      idleThreshold: const Duration(minutes: 60),
      dbFlushInterval: Duration.zero,
    );

    final day = DateTime(2025, 1, 1);
    final start = day.add(const Duration(hours: 9));
    final end = start.add(const Duration(minutes: 10));

    tracker.emit(ForegroundAppEvent(appId: 'Photoshop.exe', timestamp: start));
    tracker.emit(ForegroundAppEvent(appId: 'Browser', timestamp: end));

    await service.close();
    tracker.dispose();

    final dayKey = DateTime(2025, 1, 1);

    expect(repo.dailyMerged.containsKey(dayKey), isTrue);
    final dailyDuration = repo.dailyMerged[dayKey]!['Photoshop.exe']!;
    expect(dailyDuration.inMinutes, closeTo(10, 1));

    expect(repo.hourlyMerged.containsKey(dayKey), isTrue);
    final perHour = repo.hourlyMerged[dayKey]!;
    expect(perHour.containsKey(9), isTrue);
    final hourlyDuration = perHour[9]!['Photoshop.exe']!;
    expect(hourlyDuration.inMinutes, closeTo(10, 1));
  });
}
