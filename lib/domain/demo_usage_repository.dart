import 'dart:math';

import 'package:ringotrack/domain/usage_repository.dart';

/// 用于调试截图的内存示例数据仓库。
class DemoUsageRepository implements UsageRepository {
  DemoUsageRepository({DateTime? now})
    : _referenceDate = _normalizeDay(now ?? DateTime.now()) {
    _generateDemoData();
  }

  static const List<String> _demoAppIds = [
    'com.adobe.photoshop',
    'jp.co.celsys.clipstudiopaint',
    'org.blenderfoundation.blender',
    'com.adobe.illustrator',
    'com.figma.Desktop',
    'xmunicorn.udongman.paint',
  ];

  static const int _historyDays = 365;
  final DateTime _referenceDate;
  final Random _random = Random(DateTime.now().millisecondsSinceEpoch);
  final Map<DateTime, Map<String, Duration>> _dailyUsage = {};
  final Map<DateTime, Map<int, Map<String, Duration>>> _hourlyUsage = {};
  final Map<DateTime, Map<int, int>> _hourlyOccupancy = {};

  static DateTime _normalizeDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Duration _randomDailyDuration() {
    final ratio = pow(_random.nextDouble(), 1.4);
    final minutes = (60 + 420 * ratio).round().clamp(60, 480);
    final seconds = _random.nextInt(60);
    return Duration(minutes: minutes, seconds: seconds);
  }

  void _generateDemoData() {
    final startDay = _referenceDate.subtract(
      const Duration(days: _historyDays),
    );
    for (
      var current = startDay;
      !current.isAfter(_referenceDate);
      current = current.add(const Duration(days: 1))
    ) {
      final normalized = _normalizeDay(current);

      if (_random.nextDouble() < 0.12) {
        continue; // 休息日
      }

      final selectedApps = _selectAppsForDay();
      final dayDuration = _randomDailyDuration();
      if (dayDuration <= Duration.zero) {
        continue;
      }

      final allocations = _splitDurationAcrossApps(selectedApps, dayDuration);
      allocations.forEach((appId, duration) {
        _mergeDailyDuration(normalized, appId, duration);
        _distributeHourly(normalized, appId, duration);
      });
    }
  }

  Map<String, Duration> _splitDurationAcrossApps(
    List<String> apps,
    Duration total,
  ) {
    if (apps.isEmpty || total <= Duration.zero) {
      return {};
    }

    final totalSeconds = total.inSeconds;
    final weights = List.generate(
      apps.length,
      (_) => _random.nextDouble() + 0.1,
    );
    final totalWeight = weights.fold<double>(0, (prev, item) => prev + item);
    var remainingSeconds = totalSeconds;

    final result = <String, Duration>{};
    for (var i = 0; i < apps.length; i++) {
      final appId = apps[i];
      final slotsLeft = apps.length - i;
      final maxForThis = max(1, remainingSeconds - (slotsLeft - 1));
      final candidate = (totalSeconds * (weights[i] / totalWeight)).round();
      final share = i == apps.length - 1
          ? remainingSeconds
          : candidate.clamp(1, maxForThis);
      final finalShare = min(share, remainingSeconds);
      result[appId] = Duration(seconds: finalShare);
      remainingSeconds -= finalShare;
    }

    if (remainingSeconds > 0 && result.isNotEmpty) {
      final lastApp = apps.last;
      result[lastApp] = result[lastApp]! + Duration(seconds: remainingSeconds);
    }

    return result;
  }

  List<String> _selectAppsForDay() {
    final candidate = List<String>.from(_demoAppIds)..shuffle(_random);
    final count = 2 + _random.nextInt(3); // 2-4 个应用
    final safeCount = count.clamp(0, candidate.length).toInt();
    return candidate.take(safeCount).toList();
  }

  void _mergeDailyDuration(DateTime day, String appId, Duration duration) {
    if (duration <= Duration.zero) {
      return;
    }
    final perApp = _dailyUsage.putIfAbsent(day, () => <String, Duration>{});
    perApp[appId] = (perApp[appId] ?? Duration.zero) + duration;
  }

  void _distributeHourly(DateTime day, String appId, Duration duration) {
    if (duration <= Duration.zero) {
      return;
    }
    final segmentCount = 1 + _random.nextInt(4); // 最多跨 4 个小时
    final latestStartHour = (23 - (segmentCount - 1)).clamp(0, 23).toInt();
    const earliestStartHour = 8;
    final startHour = earliestStartHour <= latestStartHour
        ? earliestStartHour +
              _random.nextInt(latestStartHour - earliestStartHour + 1)
        : earliestStartHour;

    final maxSegments = min(segmentCount, 24 - startHour);
    final occupancyForDay = _hourlyOccupancy.putIfAbsent(
      day,
      () => <int, int>{},
    );
    var remainingSeconds = duration.inSeconds;
    var currentHour = startHour;
    var hoursAssigned = 0;

    while (remainingSeconds > 0 &&
        hoursAssigned < maxSegments &&
        currentHour < 24) {
      final existingOccupancy = occupancyForDay.putIfAbsent(
        currentHour,
        () => 0,
      );
      final capacity = max(3600 - existingOccupancy, 0);
      if (capacity <= 0) {
        currentHour++;
        continue;
      }

      final maxAllocatable = min(capacity, remainingSeconds);
      if (maxAllocatable <= 0) {
        currentHour++;
        continue;
      }

      final hoursLeft = maxSegments - hoursAssigned;
      final targetPerHour = (remainingSeconds / max(hoursLeft, 1)).ceil();
      const jitterRange = 20;
      final jitter = _random.nextInt(jitterRange * 2 + 1) - jitterRange;
      final jitteredTarget = max(1, targetPerHour + jitter);
      final chunkSeconds = min(maxAllocatable, jitteredTarget);

      final bucket = _hourlyUsage
          .putIfAbsent(day, () => <int, Map<String, Duration>>{})
          .putIfAbsent(currentHour, () => <String, Duration>{});
      bucket[appId] =
          (bucket[appId] ?? Duration.zero) + Duration(seconds: chunkSeconds);
      occupancyForDay[currentHour] = existingOccupancy + chunkSeconds;

      remainingSeconds -= chunkSeconds;
      hoursAssigned++;
      currentHour++;
    }

    while (remainingSeconds > 0 && currentHour < 24) {
      final existingOccupancy = occupancyForDay.putIfAbsent(
        currentHour,
        () => 0,
      );
      final capacity = max(3600 - existingOccupancy, 0);
      if (capacity <= 0) {
        currentHour++;
        continue;
      }

      final chunkSeconds = min(capacity, remainingSeconds);
      final bucket = _hourlyUsage
          .putIfAbsent(day, () => <int, Map<String, Duration>>{})
          .putIfAbsent(currentHour, () => <String, Duration>{});
      bucket[appId] =
          (bucket[appId] ?? Duration.zero) + Duration(seconds: chunkSeconds);
      occupancyForDay[currentHour] = existingOccupancy + chunkSeconds;

      remainingSeconds -= chunkSeconds;
      currentHour++;
    }

    if (remainingSeconds > 0) {
      final fallbackHour = min(startHour + maxSegments - 1, 23);
      final occupancyValue = occupancyForDay.putIfAbsent(fallbackHour, () => 0);
      final available = max(3600 - occupancyValue, 0);
      if (available > 0) {
        final chunkSeconds = min(available, remainingSeconds);
        final bucket = _hourlyUsage
            .putIfAbsent(day, () => <int, Map<String, Duration>>{})
            .putIfAbsent(fallbackHour, () => <String, Duration>{});
        bucket[appId] =
            (bucket[appId] ?? Duration.zero) + Duration(seconds: chunkSeconds);
        occupancyForDay[fallbackHour] = occupancyValue + chunkSeconds;
        remainingSeconds -= chunkSeconds;
      }
    }
  }

  @override
  Future<Map<DateTime, Map<String, Duration>>> loadRange(
    DateTime start,
    DateTime end,
  ) async {
    final normalizedStart = _normalizeDay(start);
    final normalizedEnd = _normalizeDay(end);
    final result = <DateTime, Map<String, Duration>>{};

    _dailyUsage.forEach((day, perApp) {
      if (day.isBefore(normalizedStart) || day.isAfter(normalizedEnd)) {
        return;
      }
      result[day] = Map<String, Duration>.from(perApp);
    });

    return result;
  }

  @override
  Future<void> mergeUsage(Map<DateTime, Map<String, Duration>> delta) async {
    if (delta.isEmpty) {
      return;
    }

    delta.forEach((day, perApp) {
      final normalized = _normalizeDay(day);
      perApp.forEach((appId, duration) {
        _mergeDailyDuration(normalized, appId, duration);
      });
    });
  }

  @override
  Future<Map<DateTime, Map<int, Map<String, Duration>>>> loadHourlyRange(
    DateTime start,
    DateTime end,
  ) async {
    final normalizedStart = _normalizeDay(start);
    final normalizedEnd = _normalizeDay(end);
    final result = <DateTime, Map<int, Map<String, Duration>>>{};

    _hourlyUsage.forEach((day, perHour) {
      if (day.isBefore(normalizedStart) || day.isAfter(normalizedEnd)) {
        return;
      }
      result[day] = perHour.map(
        (hour, perApp) => MapEntry(hour, Map<String, Duration>.from(perApp)),
      );
    });

    return result;
  }

  @override
  Future<void> mergeHourlyUsage(
    Map<DateTime, Map<int, Map<String, Duration>>> delta,
  ) async {
    if (delta.isEmpty) {
      return;
    }

    delta.forEach((day, perHour) {
      final normalized = _normalizeDay(day);
      perHour.forEach((hourIndex, perApp) {
        perApp.forEach((appId, duration) {
          if (duration <= Duration.zero) {
            return;
          }
          final bucket = _hourlyUsage
              .putIfAbsent(normalized, () => <int, Map<String, Duration>>{})
              .putIfAbsent(hourIndex, () => <String, Duration>{});
          bucket[appId] = (bucket[appId] ?? Duration.zero) + duration;
          _mergeDailyDuration(normalized, appId, duration);
        });
      });
    });
  }

  @override
  Future<void> deleteByAppId(String appId) async {
    _dailyUsage.forEach((day, perApp) {
      perApp.remove(appId);
    });
    _hourlyUsage.forEach((day, perHour) {
      perHour.forEach((_, perApp) => perApp.remove(appId));
      perHour.removeWhere((_, perApp) => perApp.isEmpty);
    });
    _dailyUsage.removeWhere((_, perApp) => perApp.isEmpty);
  }

  @override
  Future<void> deleteByDateRange(DateTime start, DateTime end) async {
    final normalizedStart = _normalizeDay(start);
    final normalizedEnd = _normalizeDay(end);
    _dailyUsage.removeWhere(
      (day, _) => day.isAfter(normalizedEnd) || day.isBefore(normalizedStart),
    );
    _hourlyUsage.removeWhere(
      (day, _) => day.isAfter(normalizedEnd) || day.isBefore(normalizedStart),
    );
  }

  @override
  Future<void> clearAll() async {
    _dailyUsage.clear();
    _hourlyUsage.clear();
  }
}
