/// 将「按日总时长」在 24 个小时桶之间回填为「按小时」的分布。
///
/// 设计目标：
/// - 单个小时桶最多 3600 秒；
/// - 同一天的数据会根据「今天 / 往日」以及当前时间的不同，采用不同的分布策略；
/// - 每个「日 + App」应独立调用本函数。
///
/// 约定：
/// - [day] 仅使用日期部分（本地时区），时间部分会被忽略；
/// - [now] 用于判断是否为「今天」以及当前所在小时。
Map<int, Duration> backfillDailyToHourly({
  required Duration total,
  required DateTime day,
  required DateTime now,
}) {
  var remaining = total.inSeconds;
  if (remaining <= 0) {
    return {};
  }

  // 一天最多只能分配 24 小时。
  const maxPerHour = 3600;
  const maxPerDay = 24 * maxPerHour;
  if (remaining > maxPerDay) {
    remaining = maxPerDay;
  }

  final buckets = <int, Duration>{};

  void assignHour(int hourIndex) {
    if (remaining <= 0) {
      return;
    }
    if (hourIndex < 0 || hourIndex > 23) {
      return;
    }

    final assignSeconds =
        remaining > maxPerHour ? maxPerHour : remaining;
    buckets[hourIndex] = Duration(seconds: assignSeconds);
    remaining -= assignSeconds;
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  final dayOnly = DateTime(day.year, day.month, day.day);
  final isToday = isSameDay(dayOnly, now);

  if (isToday) {
    final nowHour = now.hour.clamp(0, 23);

    if (nowHour < 12) {
      // 场景一：今天且当前时间在中午 12 点之前。
      // 从当前小时开始，向前倒着填充：nowHour, nowHour-1, ..., 0。
      for (var h = nowHour; h >= 0 && remaining > 0; h--) {
        assignHour(h);
      }
    } else {
      // 场景二：今天且当前时间在 12:00 之后。
      // 第一步：从 12 点开始往当前小时方向填充：12, 13, ..., nowHour。
      for (var h = 12; h <= nowHour && remaining > 0; h++) {
        assignHour(h);
      }

      // 第二步：如果还有剩余，从 11 点往前填充：11, 10, ..., 0。
      for (var h = 11; h >= 0 && remaining > 0; h--) {
        assignHour(h);
      }
    }
  } else {
    // 场景三：往日数据。
    // 第一步：从 12 点开始往当天结束填充：12, 13, ..., 23。
    for (var h = 12; h < 24 && remaining > 0; h++) {
      assignHour(h);
    }

    // 第二步：如果还有剩余，从 11 点往前填充：11, 10, ..., 0。
    for (var h = 11; h >= 0 && remaining > 0; h--) {
      assignHour(h);
    }
  }

  return buckets;
}

