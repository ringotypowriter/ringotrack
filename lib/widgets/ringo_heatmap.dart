import 'package:flutter/material.dart';

class RingoHeatmap extends StatelessWidget {
  const RingoHeatmap({
    super.key,
    required this.start,
    required this.end,
    required this.dailyTotals,
    this.baseColor = Colors.green,
    this.emptyColor = const Color(0xFFE3E3E3),
    this.tileSize = 14,
    this.spacing = 4,
    this.showMonthLabels = true,
    this.showWeekdayLabels = true,
    this.weekdayLabelWidth = 24,
    this.weekdayLabelGap = 20,
    this.headerToGridSpacing = 16,
    this.monthLabelStyle,
    this.weekdayLabelStyle,
    this.emptyPlaceholder,
  });

  final DateTime start;
  final DateTime end;
  final Map<DateTime, Duration> dailyTotals;
  final Color baseColor;
  final Color emptyColor;
  final double tileSize;
  final double spacing;
  final bool showMonthLabels;
  final bool showWeekdayLabels;
  final double weekdayLabelWidth;
  final double weekdayLabelGap;
  final double headerToGridSpacing;
  final TextStyle? monthLabelStyle;
  final TextStyle? weekdayLabelStyle;
  final Widget? emptyPlaceholder;

  @override
  Widget build(BuildContext context) {
    final normalizedStart = _normalizeDate(start);
    final normalizedEnd = _normalizeDate(end);

    // 归一化日期键，确保 Map 查找使用的是 yyyy-MM-dd
    final normalizedTotals = <DateTime, Duration>{};
    dailyTotals.forEach((date, duration) {
      final day = _normalizeDate(date);
      final existing = normalizedTotals[day];
      if (existing == null || duration > existing) {
        normalizedTotals[day] = duration;
      }
    });

    final calendarStart = _startOfWeek(normalizedStart);
    final totalDays = normalizedEnd.difference(calendarStart).inDays + 1;
    final weekCount = (totalDays / 7).ceil();

    final gridWidth = weekCount * tileSize + (weekCount - 1) * spacing;
    final gridHeight = 7 * tileSize + 6 * spacing;
    final totalWidth =
        (showWeekdayLabels ? weekdayLabelWidth + weekdayLabelGap : 0) +
            gridWidth;

    final resolvedMonthLabelStyle = monthLabelStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
            );

    final resolvedWeekdayLabelStyle = weekdayLabelStyle ??
        Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            );

    final monthLabelHeight =
        (resolvedMonthLabelStyle?.fontSize ?? 14) * 1.4;

    final children = <Widget>[];

    if (showMonthLabels) {
      children.add(
        SizedBox(
          height: monthLabelHeight,
          child: Stack(
            children: _buildMonthLabels(
              style: resolvedMonthLabelStyle,
              calendarStart: calendarStart,
              normalizedStart: normalizedStart,
              normalizedEnd: normalizedEnd,
            ),
          ),
        ),
      );

      children.add(SizedBox(height: headerToGridSpacing));
    }

    final gridArea = normalizedTotals.isEmpty && emptyPlaceholder != null
        ? SizedBox(
            width: gridWidth,
            height: gridHeight,
            child: Center(child: emptyPlaceholder),
          )
        : SizedBox(
            width: gridWidth,
            child: _buildGrid(
              context: context,
              calendarStart: calendarStart,
              weekCount: weekCount,
              normalizedStart: normalizedStart,
              normalizedEnd: normalizedEnd,
              normalizedTotals: normalizedTotals,
            ),
          );

    children.add(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showWeekdayLabels)
            SizedBox(
              width: weekdayLabelWidth,
              child: _buildWeekdayLabels(
                spacing: spacing,
                tileSize: tileSize,
                style: resolvedWeekdayLabelStyle,
              ),
            ),
          if (showWeekdayLabels) SizedBox(width: weekdayLabelGap),
          gridArea,
        ],
      ),
    );

    return SizedBox(
      width: totalWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  List<Widget> _buildMonthLabels({
    required TextStyle? style,
    required DateTime calendarStart,
    required DateTime normalizedStart,
    required DateTime normalizedEnd,
  }) {
    final labels = <_MonthPosition>[];
    final year = normalizedStart.year;

    for (var month = 1; month <= 12; month++) {
      final firstDayOfMonth = DateTime(year, month, 1);
      if (firstDayOfMonth.isBefore(normalizedStart) ||
          firstDayOfMonth.isAfter(normalizedEnd)) {
        continue;
      }

      final diffDays = firstDayOfMonth.difference(calendarStart).inDays;
      final columnIndex = diffDays ~/ 7;

      labels.add(_MonthPosition(month: month, columnIndex: columnIndex));
    }

    return labels
        .map(
          (label) => Positioned(
            left: (showWeekdayLabels
                    ? weekdayLabelWidth + weekdayLabelGap
                    : 0) +
                label.columnIndex * (tileSize + spacing),
            child: Text('${label.month}月', style: style),
          ),
        )
        .toList();
  }

  Widget _buildWeekdayLabels({
    required double tileSize,
    required double spacing,
    required TextStyle? style,
  }) {
    const labels = ['日', '一', '二', '三', '四', '五', '六'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == labels.length - 1 ? 0 : spacing,
            ),
            child: SizedBox(
              height: tileSize,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  child: Text(labels[i], style: style),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGrid({
    required BuildContext context,
    required DateTime calendarStart,
    required int weekCount,
    required DateTime normalizedStart,
    required DateTime normalizedEnd,
    required Map<DateTime, Duration> normalizedTotals,
  }) {
    // 计算当前视图下的「非 0 天」平均时长和最大时长，
    // 用于后续做相对/绝对混合的颜色映射。
    final nonZeroMinutes = normalizedTotals.values
        .where((d) => d.inMinutes > 0)
        .map((d) => d.inMinutes)
        .toList();

    final double avgMinutes;
    final int maxMinutes;
    if (nonZeroMinutes.isEmpty) {
      avgMinutes = 0;
      maxMinutes = 0;
    } else {
      final totalMinutes =
          nonZeroMinutes.fold<int>(0, (sum, m) => sum + m);
      avgMinutes = totalMinutes / nonZeroMinutes.length;
      maxMinutes = nonZeroMinutes.reduce((a, b) => a > b ? a : b);
    }

    final columns = <Widget>[];

    for (var week = 0; week < weekCount; week++) {
      final tiles = <Widget>[];

      for (var i = 0; i < 7; i++) {
        final date = calendarStart.add(Duration(days: week * 7 + i));
        final normalized = _normalizeDate(date);
         final isInRange = !normalized.isBefore(normalizedStart) &&
            !normalized.isAfter(normalizedEnd);

        final duration =
            isInRange ? normalizedTotals[normalized] ?? Duration.zero : Duration.zero;

        final color = isInRange
            ? _colorForDuration(
                duration,
                avgMinutes: avgMinutes,
                maxMinutes: maxMinutes,
              )
            : Colors.transparent;

        Widget tile = Container(
          key: ValueKey(_dayKey(normalized)),
          width: tileSize,
          height: tileSize,
          color: color,
        );

        if (isInRange) {
          final tooltipText = _tooltipLabel(normalized, duration);
          tile = Tooltip(
            message: tooltipText,
            waitDuration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(6),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                ),
            preferBelow: false,
            verticalOffset: 8,
            child: tile,
          );
        }

        tiles.add(tile);

        if (i != 6) {
          tiles.add(SizedBox(height: spacing));
        }
      }

      columns.add(
        Padding(
          padding:
              EdgeInsets.only(right: week == weekCount - 1 ? 0 : spacing),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: tiles,
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columns,
    );
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = _normalizeDate(date);
    final weekday = normalized.weekday % 7; // 周日 = 0
    return normalized.subtract(Duration(days: weekday));
  }

  String _tooltipLabel(DateTime day, Duration duration) {
    final dateLabel =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final durationLabel = _formatDuration(duration);
    return '$dateLabel · $durationLabel';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes <= 0) {
      return '0 分钟';
    }
    final hours = duration.inHours;
    final remainMinutes = minutes % 60;
    if (hours > 0 && remainMinutes > 0) {
      return '${hours} 小时 ${remainMinutes} 分钟';
    }
    if (hours > 0) {
      return '${hours} 小时';
    }
    return '$minutes 分钟';
  }

  /// 结合「相对平均值」和「绝对时长」的热力颜色映射。
  ///
  /// 设计目标：
  /// 1. 相对：比自己平时更肝的日子明显更深。
  ///    - 使用 avgMinutes 作为基准，1.5x、1.75x、2x、2.25x、2.5x 为主要分界。
  /// 2. 绝对：不让大时长被“平均抹平”，比如 > 5 小时时至少 0.5 的深度。
  ///    - 以 5h 作为一个绝对基准点，再向前/向后划分多个档位。
  /// 3. 最终把相对/绝对两种强度取最大值，再离散到 5 个 tier 上映射为透明度。
  Color _colorForDuration(
    Duration duration, {
    required double avgMinutes,
    required int maxMinutes,
  }) {
    final minutes = duration.inMinutes;

    // 没有记录：用中性灰，保持 GitHub 风格。
    if (minutes <= 0) {
      return emptyColor;
    }

    // -------- 相对强度：当前天 vs 非 0 天平均值 --------
    double relativeScore = 0;
    if (avgMinutes > 0) {
      final ratio = minutes / avgMinutes;

      // 这里刻意用分段函数，而不是简单线性，
      // 在 1.5x、1.75x、2x、2.25x、2.5x 附近设置多个台阶。
      if (ratio < 0.5) {
        relativeScore = 0.10;
      } else if (ratio < 1.0) {
        relativeScore = 0.22;
      } else if (ratio < 1.5) {
        relativeScore = 0.34;
      } else if (ratio < 1.75) {
        relativeScore = 0.52;
      } else if (ratio < 2.0) {
        relativeScore = 0.64;
      } else if (ratio < 2.25) {
        relativeScore = 0.76;
      } else if (ratio < 2.5) {
        relativeScore = 0.88;
      } else {
        relativeScore = 1.0;
      }
    }

    // -------- 绝对强度：独立于平均值的“肝度” --------
    //
    // 以 5h 作为核心基准：
    // - < 0.5h      : 很浅
    // - 0.5h–2h     : 稍明显
    // - 2h–4h       : 中等
    // - 4h–5h       : 偏深
    // - ≥ 5h        : 至少 0.5，再继续随总长略微增加
    double absoluteScore;
    if (minutes < 30) {
      absoluteScore = 0.12;
    } else if (minutes < 120) {
      absoluteScore = 0.26;
    } else if (minutes < 240) {
      absoluteScore = 0.40;
    } else if (minutes < 300) {
      absoluteScore = 0.48;
    } else {
      // 5h 起步给 0.52，后面根据相对 5h 的倍数缓慢提高。
      final overBase = minutes / 300.0; // 以 5h 为 1.0
      // 上限不超过 1.0，避免无限加深。
      absoluteScore = 0.52 + (overBase - 1.0) * 0.20;
      if (absoluteScore > 1.0) {
        absoluteScore = 1.0;
      }
    }

    // 如果用户某段时间异常猛（例如 maxMinutes 特别高），
    // 为了不让普通高强度日子全部被压在浅色，可以用 max 做一点归一化保护。
    // 这里对所有非 0 日都做一次线性混合，保证随分钟数单调不减。
    if (maxMinutes > 0) {
      final normalized = minutes / maxMinutes;
      // 稍微抬一抬中高区间的下限，让“中游高强度”不会太暗，
      // 同时让最高强度的日子稳定落在最深的 tier 上。
      absoluteScore = absoluteScore * 0.7 + normalized * 0.3;
    }

    // -------- 最终强度：取相对 vs 绝对中的最大值 --------
    var intensity = relativeScore > absoluteScore
        ? relativeScore
        : absoluteScore;

    // 强度落在 0.0–1.0 区间；然后映射到 5 个离散 tier，
    // 保证视觉上有明确的层级感。
    if (intensity < 0.20) {
      intensity = 0.20;
    } else if (intensity < 0.40) {
      intensity = 0.40;
    } else if (intensity < 0.60) {
      intensity = 0.60;
    } else if (intensity < 0.80) {
      intensity = 0.80;
    } else {
      intensity = 1.0;
    }

    return baseColor.withOpacity(intensity);
  }

  String _dayKey(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return 'day-$y-$m-$d';
  }
}

class _MonthPosition {
  const _MonthPosition({required this.month, required this.columnIndex});

  final int month;
  final int columnIndex;
}
