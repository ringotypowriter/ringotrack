import 'package:flutter/material.dart';

class RingoHeatmap extends StatelessWidget {
  const RingoHeatmap({
    super.key,
    required this.start,
    required this.end,
    required this.dailyTotals,
    this.baseColor = Colors.green,
    this.tileSize = 14,
    this.spacing = 4,
  });

  final DateTime start;
  final DateTime end;
  final Map<DateTime, Duration> dailyTotals;
  final Color baseColor;
  final double tileSize;
  final double spacing;

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

    return SizedBox(
      width: gridWidth,
      child: _buildGrid(
        calendarStart: calendarStart,
        weekCount: weekCount,
        normalizedStart: normalizedStart,
        normalizedEnd: normalizedEnd,
        normalizedTotals: normalizedTotals,
      ),
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

  static const Color _emptyColor = Color(0xFFE3E3E3);

  Color _colorForDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes <= 0) {
      // 0 记录使用中性灰色，效果与 GitHub 类似
      return _emptyColor;
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
