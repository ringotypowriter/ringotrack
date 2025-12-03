class AppUsageEntry {
  AppUsageEntry({
    required this.appId,
    required this.duration,
  });

  final String appId;
  final Duration duration;
}

class DailyUsage {
  DailyUsage({
    required this.date,
    required this.perApp,
  });

  final DateTime date;
  final Map<String, Duration> perApp;

  Duration totalDuration() {
    return perApp.values.fold(Duration.zero, (a, b) => a + b);
  }
}

class ForegroundAppEvent {
  ForegroundAppEvent({
    required this.appId,
    required this.timestamp,
  });

  final String appId;
  final DateTime timestamp;
}

class UsageAggregator {
  UsageAggregator({
    required this.isDrawingApp,
  });

  final bool Function(String appId) isDrawingApp;

  final Map<DateTime, Map<String, Duration>> _usage = {};

  String? _currentAppId;
  DateTime? _currentStart;

  Map<DateTime, Map<String, Duration>> get usageByDate {
    return _usage.map((key, value) => MapEntry(key, Map.of(value)));
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
      final dayEnd = DateTime(cursor.year, cursor.month, cursor.day)
          .add(const Duration(days: 1));
      final segmentEnd = end.isBefore(dayEnd) ? end : dayEnd;
      final segmentDuration = segmentEnd.difference(cursor);

      final dayKey = DateTime(cursor.year, cursor.month, cursor.day);
      final perApp = _usage.putIfAbsent(dayKey, () => {});
      perApp[appId] = (perApp[appId] ?? Duration.zero) + segmentDuration;

      cursor = segmentEnd;
    }
  }
}

