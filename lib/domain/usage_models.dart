class AppUsageEntry {
  AppUsageEntry({required this.appId, required this.duration});

  final String appId;
  final Duration duration;
}

class DailyUsage {
  DailyUsage({required this.date, required this.perApp});

  final DateTime date;
  final Map<String, Duration> perApp;

  Duration totalDuration() {
    return perApp.values.fold(Duration.zero, (a, b) => a + b);
  }
}

class ForegroundAppEvent {
  ForegroundAppEvent({required this.appId, required this.timestamp});

  final String appId;
  final DateTime timestamp;
}

class UsageAggregator {
  UsageAggregator({required this.isDrawingApp});

  final bool Function(String appId) isDrawingApp;

  final Map<DateTime, Map<String, Duration>> _usage = {};

  String? _currentAppId;
  DateTime? _currentStart;

  Map<DateTime, Map<String, Duration>> get usageByDate {
    return _usage.map((key, value) => MapEntry(key, Map.of(value)));
  }

  /// 取出当前累计的 usage 并清空内部缓存，用于与持久化层做增量同步。
  Map<DateTime, Map<String, Duration>> drainUsage() {
    final snapshot = usageByDate;
    _usage.clear();
    return snapshot;
  }

  void onForegroundAppChanged(ForegroundAppEvent event) {
    if (_currentAppId != null && _currentStart != null) {
      _addInterval(_currentAppId!, _currentStart!, event.timestamp);
    }

    _currentAppId = event.appId;
    _currentStart = event.timestamp;
  }

  void closeAt(DateTime now) {
    if (_currentAppId != null && _currentStart != null) {
      _addInterval(_currentAppId!, _currentStart!, now);
      _currentAppId = null;
      _currentStart = null;
    }
  }

  void _addInterval(String appId, DateTime start, DateTime end) {
    if (!isDrawingApp(appId)) {
      return;
    }

    if (!start.isBefore(end)) {
      return;
    }

    var cursor = start;
    while (cursor.isBefore(end)) {
      final dayEnd = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
      ).add(const Duration(days: 1));
      final segmentEnd = end.isBefore(dayEnd) ? end : dayEnd;
      final segmentDuration = segmentEnd.difference(cursor);

      final dayKey = DateTime(cursor.year, cursor.month, cursor.day);
      final perApp = _usage.putIfAbsent(dayKey, () => {});
      perApp[appId] = (perApp[appId] ?? Duration.zero) + segmentDuration;

      cursor = segmentEnd;
    }
  }
}

/// 小时级聚合器：将前台应用区间拆分为「日 + 小时 + App」的用时。
class HourlyUsageAggregator {
  HourlyUsageAggregator({required this.isDrawingApp});

  final bool Function(String appId) isDrawingApp;

  final Map<DateTime, Map<int, Map<String, Duration>>> _usage = {};

  String? _currentAppId;
  DateTime? _currentStart;

  Map<DateTime, Map<int, Map<String, Duration>>> get usageByDateHour {
    return _usage.map((day, perHour) {
      final perHourCopy = perHour.map(
        (hour, perApp) => MapEntry(hour, Map.of(perApp)),
      );
      return MapEntry(day, perHourCopy);
    });
  }

  /// 取出当前累计的 usage 并清空内部缓存，用于与持久化层做增量同步。
  Map<DateTime, Map<int, Map<String, Duration>>> drainUsage() {
    final snapshot = usageByDateHour;
    _usage.clear();
    return snapshot;
  }

  void onForegroundAppChanged(ForegroundAppEvent event) {
    if (_currentAppId != null && _currentStart != null) {
      _addInterval(_currentAppId!, _currentStart!, event.timestamp);
    }

    _currentAppId = event.appId;
    _currentStart = event.timestamp;
  }

  void closeAt(DateTime now) {
    if (_currentAppId != null && _currentStart != null) {
      _addInterval(_currentAppId!, _currentStart!, now);
      _currentAppId = null;
      _currentStart = null;
    }
  }

  void _addInterval(String appId, DateTime start, DateTime end) {
    if (!isDrawingApp(appId)) {
      return;
    }

    if (!start.isBefore(end)) {
      return;
    }

    var cursor = start;
    while (cursor.isBefore(end)) {
      final nextHourStart = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        cursor.hour,
      ).add(const Duration(hours: 1));

      final segmentEnd = end.isBefore(nextHourStart) ? end : nextHourStart;
      final segmentDuration = segmentEnd.difference(cursor);

      final dayKey = DateTime(cursor.year, cursor.month, cursor.day);
      final hourIndex = cursor.hour;

      final perHour = _usage.putIfAbsent(
        dayKey,
        () => <int, Map<String, Duration>>{},
      );
      final perApp = perHour.putIfAbsent(
        hourIndex,
        () => <String, Duration>{},
      );

      perApp[appId] = (perApp[appId] ?? Duration.zero) + segmentDuration;

      cursor = segmentEnd;
    }
  }
}
