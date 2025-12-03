class UsageRepository {
  UsageRepository();

  final Map<DateTime, Map<String, Duration>> _store = {};

  Map<DateTime, Map<String, Duration>> loadRange(
    DateTime start,
    DateTime end,
  ) {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    final result = <DateTime, Map<String, Duration>>{};

    for (final entry in _store.entries) {
      final day = entry.key;
      if (day.isBefore(startDay) || day.isAfter(endDay)) {
        continue;
      }
      result[day] = Map.of(entry.value);
    }

    return result;
  }

  void mergeUsage(Map<DateTime, Map<String, Duration>> delta) {
    for (final entry in delta.entries) {
      final dayKey = DateTime(entry.key.year, entry.key.month, entry.key.day);
      final targetPerApp = _store.putIfAbsent(dayKey, () => {});

      for (final appEntry in entry.value.entries) {
        final appId = appEntry.key;
        final duration = appEntry.value;
        targetPerApp[appId] = (targetPerApp[appId] ?? Duration.zero) + duration;
      }
    }
  }
}

