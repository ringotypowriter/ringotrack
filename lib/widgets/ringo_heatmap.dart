import 'package:flutter/material.dart';
import 'package:ringotrack/widgets/heatmap_color_scale.dart';

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

    final resolvedMonthLabelStyle =
        monthLabelStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87);

    final resolvedWeekdayLabelStyle =
        weekdayLabelStyle ??
        Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54);

    final monthLabelHeight = (resolvedMonthLabelStyle?.fontSize ?? 14) * 1.4;

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
            height: gridHeight,
            child: _HeatmapGrid(
              calendarStart: calendarStart,
              weekCount: weekCount,
              normalizedStart: normalizedStart,
              normalizedEnd: normalizedEnd,
              normalizedTotals: normalizedTotals,
              tileSize: tileSize,
              spacing: spacing,
              baseColor: baseColor,
              emptyColor: emptyColor,
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
    var cursor = DateTime(normalizedStart.year, normalizedStart.month, 1);

    while (!cursor.isAfter(normalizedEnd)) {
      if (!cursor.isBefore(normalizedStart)) {
        final diffDays = cursor.difference(calendarStart).inDays;
        final columnIndex = diffDays ~/ 7;

        labels.add(
          _MonthPosition(month: cursor.month, columnIndex: columnIndex),
        );
      }

      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return labels
        .map(
          (label) => Positioned(
            left:
                (showWeekdayLabels ? weekdayLabelWidth + weekdayLabelGap : 0) +
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

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = _normalizeDate(date);
    final weekday = normalized.weekday % 7; // 周日 = 0
    return normalized.subtract(Duration(days: weekday));
  }
}

class _MonthPosition {
  const _MonthPosition({required this.month, required this.columnIndex});

  final int month;
  final int columnIndex;
}

class _HeatmapGrid extends StatefulWidget {
  const _HeatmapGrid({
    required this.calendarStart,
    required this.weekCount,
    required this.normalizedStart,
    required this.normalizedEnd,
    required this.normalizedTotals,
    required this.tileSize,
    required this.spacing,
    required this.baseColor,
    required this.emptyColor,
  });

  final DateTime calendarStart;
  final int weekCount;
  final DateTime normalizedStart;
  final DateTime normalizedEnd;
  final Map<DateTime, Duration> normalizedTotals;
  final double tileSize;
  final double spacing;
  final Color baseColor;
  final Color emptyColor;

  @override
  State<_HeatmapGrid> createState() => _HeatmapGridState();
}

class _HeatmapGridState extends State<_HeatmapGrid> {
  DateTime? _hoveredDay;
  Duration _hoveredDuration = Duration.zero;

  late double _avgMinutes;
  late double _maxMinutes;

  @override
  void initState() {
    super.initState();
    _recomputeStats();
  }

  @override
  void didUpdateWidget(covariant _HeatmapGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.normalizedTotals, widget.normalizedTotals)) {
      _recomputeStats();
    }
  }

  void _recomputeStats() {
    final nonZeroDurations = widget.normalizedTotals.values
        .where((d) => d.inSeconds > 0)
        .toList();

    if (nonZeroDurations.isEmpty) {
      _avgMinutes = 0;
      _maxMinutes = 0;
      return;
    }

    final minutesList = nonZeroDurations
        .map((d) => d.inSeconds / 60.0)
        .toList();

    final totalMinutes = minutesList.fold<double>(0, (sum, m) => sum + m);
    _avgMinutes = totalMinutes / minutesList.length;
    _maxMinutes = minutesList.reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final columns = <Widget>[];

    for (var week = 0; week < widget.weekCount; week++) {
      final tiles = <Widget>[];

      for (var i = 0; i < 7; i++) {
        final date = widget.calendarStart.add(Duration(days: week * 7 + i));
        final normalized = DateTime(date.year, date.month, date.day);

        final isInRange =
            !normalized.isBefore(widget.normalizedStart) &&
            !normalized.isAfter(widget.normalizedEnd);

        final duration = isInRange
            ? widget.normalizedTotals[normalized] ?? Duration.zero
            : Duration.zero;

        final color = isInRange
            ? HeatmapColorScale.colorForDuration(
                duration,
                avgMinutes: _avgMinutes,
                maxMinutes: _maxMinutes,
                baseColor: widget.baseColor,
                emptyColor: widget.emptyColor,
              )
            : Colors.transparent;

        Widget tile = Container(
          key: ValueKey(_dayKey(normalized)),
          width: widget.tileSize,
          height: widget.tileSize,
          color: color,
        );

        if (isInRange) {
          tile = MouseRegion(
            onEnter: (_) {
              setState(() {
                _hoveredDay = normalized;
                _hoveredDuration = duration;
              });
            },
            onExit: (_) {
              setState(() {
                if (_hoveredDay == normalized) {
                  _hoveredDay = null;
                  _hoveredDuration = Duration.zero;
                }
              });
            },
            child: tile,
          );
        }

        tiles.add(tile);

        if (i != 6) {
          tiles.add(SizedBox(height: widget.spacing));
        }
      }

      columns.add(
        Padding(
          padding: EdgeInsets.only(
            right: week == widget.weekCount - 1 ? 0 : widget.spacing,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: tiles,
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: columns),
        if (_hoveredDay != null) _buildHoverBubble(context),
      ],
    );
  }

  Widget _buildHoverBubble(BuildContext context) {
    final hovered = _hoveredDay!;
    final diffDays = hovered.difference(widget.calendarStart).inDays;
    final weekIndex = diffDays ~/ 7;
    final weekdayIndex = diffDays % 7;

    final left = weekIndex * (widget.tileSize + widget.spacing);
    final top = weekdayIndex * (widget.tileSize + widget.spacing) - 32;

    final label = _tooltipLabel(hovered, _hoveredDuration);

    final textStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white) ??
        const TextStyle(color: Colors.white, fontSize: 12);

    return Positioned(
      left: left,
      top: top,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: textStyle),
      ),
    );
  }

  String _tooltipLabel(DateTime day, Duration duration) {
    final dateLabel =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final durationLabel = _formatDuration(duration);
    return '$dateLabel · $durationLabel';
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0) {
      return '0s';
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h '
          '${minutes.toString().padLeft(2, '0')}m '
          '${seconds.toString().padLeft(2, '0')}s';
    }

    if (minutes > 0) {
      return '${minutes}m '
          '${seconds.toString().padLeft(2, '0')}s';
    }

    return '${seconds}s';
  }

  String _dayKey(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return 'day-$y-$m-$d';
  }
}
