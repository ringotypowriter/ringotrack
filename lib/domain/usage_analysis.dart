/// 提供给「分析页」用的数据聚合工具。
///
/// 输入是「按天 + app」的时长字典，输出常见的分析维度：
/// - 日总时长序列（补零、保持日期顺序）
/// - 周总时长（周一作为一周起点）
/// - 按 App 的总时长
/// - 按星期的平均时长
class UsageAnalysis {
  UsageAnalysis(this._usageByDate);

  final Map<DateTime, Map<String, Duration>> _usageByDate;

  /// 按日期返回总时长，缺失日期会补零。
  List<DailyTotal> dailyTotals(DateTime start, DateTime end) {
    final normalizedStart = _normalizeDay(start);
    final normalizedEnd = _normalizeDay(end);
    final days = _daysInRange(normalizedStart, normalizedEnd);

    return days
        .map((day) {
          final perApp = _usageByDate[_normalizeDay(day)] ?? const {};
          final total = perApp.values.fold(Duration.zero, (acc, d) => acc + d);
          return DailyTotal(date: day, total: total, perApp: Map.of(perApp));
        })
        .toList(growable: false);
  }

  /// 按周（周一起点）汇总时长。
  List<WeeklyTotal> weeklyTotals(DateTime start, DateTime end) {
    final normalizedStart = _normalizeDay(start);
    final normalizedEnd = _normalizeDay(end);
    final days = _daysInRange(normalizedStart, normalizedEnd);

    final buckets = <DateTime, Map<String, Duration>>{};

    for (final day in days) {
      final weekStart = _weekStart(day);
      final perApp = _usageByDate[_normalizeDay(day)];
      if (perApp == null) {
        // 没有数据也要确保周 bucket 存在，便于后续填零
        buckets.putIfAbsent(weekStart, () => {});
        continue;
      }

      final bucket = buckets.putIfAbsent(weekStart, () => {});
      perApp.forEach((appId, duration) {
        bucket[appId] = (bucket[appId] ?? Duration.zero) + duration;
      });
    }

    final sortedWeekStarts = buckets.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return sortedWeekStarts
        .map((weekStart) {
          final perApp = buckets[weekStart] ?? const {};
          final total = perApp.values.fold(Duration.zero, (acc, d) => acc + d);
          return WeeklyTotal(
            weekStart: weekStart,
            total: total,
            perApp: Map.of(perApp),
          );
        })
        .toList(growable: false);
  }

  /// 指定日期范围内，按 app 汇总时长。
  List<AppTotal> appTotals(DateTime start, DateTime end) {
    final normalizedStart = _normalizeDay(start);
    final normalizedEnd = _normalizeDay(end);
    final days = _daysInRange(normalizedStart, normalizedEnd);

    final totals = <String, Duration>{};
    for (final day in days) {
      final perApp = _usageByDate[_normalizeDay(day)];
      if (perApp == null) continue;
      perApp.forEach((appId, duration) {
        totals[appId] = (totals[appId] ?? Duration.zero) + duration;
      });
    }

    final entries = totals.entries
        .map((e) => AppTotal(appId: e.key, total: e.value))
        .toList();

    entries.sort((a, b) => b.total.compareTo(a.total));
    return entries;
  }

  /// 以星期（周一=1）为维度的平均值，除数为该范围内对应星期的日历天数。
  List<WeekdayAverage> weekdayAverages(DateTime start, DateTime end) {
    final normalizedStart = _normalizeDay(start);
    final normalizedEnd = _normalizeDay(end);
    final days = _daysInRange(normalizedStart, normalizedEnd);

    final sums = List.filled(7, Duration.zero);
    final counts = List.filled(7, 0);

    for (final day in days) {
      final weekdayIndex = day.weekday - 1; // 0-6
      counts[weekdayIndex] += 1;
      final perApp = _usageByDate[_normalizeDay(day)];
      if (perApp == null) continue;
      final total = perApp.values.fold(Duration.zero, (acc, d) => acc + d);
      sums[weekdayIndex] += total;
    }

    return List.generate(7, (i) {
      final count = counts[i];
      final average = count == 0 ? Duration.zero : sums[i] ~/ count;
      final weekday = i + 1; // DateTime weekday 1-7
      return WeekdayAverage(weekday: weekday, average: average);
    });
  }
}

class DailyTotal {
  DailyTotal({required this.date, required this.total, required this.perApp});

  final DateTime date;
  final Duration total;
  final Map<String, Duration> perApp;
}

class WeeklyTotal {
  WeeklyTotal({
    required this.weekStart,
    required this.total,
    required this.perApp,
  });

  /// 周一起点
  final DateTime weekStart;
  final Duration total;
  final Map<String, Duration> perApp;
}

class AppTotal {
  AppTotal({required this.appId, required this.total});

  final String appId;
  final Duration total;
}

class WeekdayAverage {
  WeekdayAverage({required this.weekday, required this.average});

  /// DateTime 周数字：周一=1，周日=7
  final int weekday;
  final Duration average;
}

/// 小时级分析工具：基于「按日 + 小时 + app」的时长字典，
/// 给出某一天 24 小时的用时分布。
class HourlyUsageAnalysis {
  HourlyUsageAnalysis(this._usageByDateHour);

  final Map<DateTime, Map<int, Map<String, Duration>>> _usageByDateHour;

  /// 返回指定日期在 24 个小时内的用时分布。
  ///
  /// - 如果某个小时没有任何记录，会补零；
  /// - [perApp] 为该小时按 app 分组的时长；
  /// - [total] 为该小时所有 app 的总用时。
  List<HourlyBucket> hourlyBuckets(DateTime day) {
    final normalizedDay = _normalizeDay(day);
    final perHour = _usageByDateHour[normalizedDay] ?? const {};

    return List<HourlyBucket>.generate(24, (index) {
      final hourData = perHour[index] ?? const {};
      final total =
          hourData.values.fold(Duration.zero, (acc, d) => acc + d);
      return HourlyBucket(
        date: normalizedDay,
        hourIndex: index,
        total: total,
        perApp: Map.of(hourData),
      );
    }, growable: false);
  }
}

class HourlyBucket {
  HourlyBucket({
    required this.date,
    required this.hourIndex,
    required this.total,
    required this.perApp,
  });

  /// 所属日期（归一化到当天 00:00）
  final DateTime date;

  /// 当天的第几个小时（0-23）
  final int hourIndex;

  /// 该小时总用时
  final Duration total;

  /// 该小时按 app 拆分的用时
  final Map<String, Duration> perApp;
}

DateTime _normalizeDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

Iterable<DateTime> _daysInRange(DateTime start, DateTime end) sync* {
  if (end.isBefore(start)) return;
  var cursor = start;
  while (!cursor.isAfter(end)) {
    yield cursor;
    cursor = cursor.add(const Duration(days: 1));
  }
}

DateTime _weekStart(DateTime day) {
  final normalized = _normalizeDay(day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}
