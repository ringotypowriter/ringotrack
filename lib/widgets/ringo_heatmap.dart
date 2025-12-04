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
    required DateTime calendarStart,
    required int weekCount,
    required DateTime normalizedStart,
    required DateTime normalizedEnd,
    required Map<DateTime, Duration> normalizedTotals,
  }) {
    final columns = <Widget>[];

    for (var week = 0; week < weekCount; week++) {
      final tiles = <Widget>[];

      for (var i = 0; i < 7; i++) {
        final date = calendarStart.add(Duration(days: week * 7 + i));
        final normalized = _normalizeDate(date);

        Color color;
        if (normalized.isBefore(normalizedStart) ||
            normalized.isAfter(normalizedEnd)) {
          color = Colors.transparent;
        } else {
          final duration = normalizedTotals[normalized] ?? Duration.zero;
          color = _colorForDuration(duration);
        }

        tiles.add(
          Container(
            key: ValueKey(_dayKey(normalized)),
            width: tileSize,
            height: tileSize,
            color: color,
          ),
        );

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

  Color _colorForDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes <= 0) {
      // 0 记录使用中性灰色，效果与 GitHub 类似
      return emptyColor;
    }
    if (minutes < 60) {
      return baseColor.withOpacity(0.4);
    }
    if (minutes < 180) {
      return baseColor.withOpacity(0.7);
    }
    return baseColor.withOpacity(1);
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
