import 'package:flutter/material.dart';
import 'package:ringotrack/widgets/ringo_heatmap.dart';

const double _heatmapTileSize = 10;
const double _heatmapTileSpacing = 3;

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.start,
    required this.end,
    required this.dailyTotals,
  });

  final DateTime start;
  final DateTime end;
  final Map<DateTime, Duration> dailyTotals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440, maxHeight: 900),
          child: Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(theme),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 64,
                      vertical: 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryRow(theme),
                        const SizedBox(height: 40),
                        _buildTabs(theme),
                        const SizedBox(height: 16),
                        _buildHeatmapShell(theme),
                        const SizedBox(height: 24),
                        _buildFooter(theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF4AC26B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '仪表盘',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const Spacer(),
          Text('设置', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(ThemeData theme) {
    final titles = ['今日时长', '本周时长', '本月时长', '连续天数'];

    return Row(
      children: [
        for (var i = 0; i < titles.length; i++) ...[
          Expanded(
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: const Color(0xFFE3E3E3)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    titles[i],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        i == 3 ? '12 天' : '0h 00m',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (i != titles.length - 1) const SizedBox(width: 24),
        ],
      ],
    );
  }

  Widget _buildTabs(ThemeData theme) {
    final selectedColor = const Color(0xFF4AC26B);

    return Row(
      children: [
        _TabButton(label: '总览', isSelected: true, selectedColor: selectedColor),
        const SizedBox(width: 8),
        const _TabButton(label: '按软件', isSelected: false),
        const SizedBox(width: 8),
        const _TabButton(label: '分组', isSelected: false),
      ],
    );
  }

  Widget _buildHeatmapShell(ThemeData theme) {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    final calendarStart = _startOfWeek(normalizedStart);
    final totalDays = normalizedEnd.difference(calendarStart).inDays + 1;
    final weekCount = (totalDays / 7).ceil();

    return Container(
      key: const ValueKey('dashboard-heatmap-shell'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMonthHeader(
            theme: theme,
            calendarStart: calendarStart,
            weekCount: weekCount,
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWeekdayLabels(theme),
              const SizedBox(width: 24),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: RingoHeatmap(
                    start: start,
                    end: end,
                    dailyTotals: dailyTotals,
                    baseColor: const Color(0xFF4AC26B),
                    tileSize: _heatmapTileSize,
                    spacing: _heatmapTileSpacing,
                  ),
                ),
              ),
            ],
          ),
          _buildLegend(theme),
        ],
      ),
    );
  }

  Widget _buildMonthHeader({
    required ThemeData theme,
    required DateTime calendarStart,
    required int weekCount,
  }) {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);

    final labels = <_MonthPosition>[];
    final year = start.year;

    for (var month = 1; month <= 12; month++) {
      final firstDayOfMonth = DateTime(year, month, 1);
      if (firstDayOfMonth.isBefore(normalizedStart) ||
          firstDayOfMonth.isAfter(normalizedEnd)) {
        continue;
      }

      final diffDays = firstDayOfMonth.difference(calendarStart).inDays;
      final columnIndex = diffDays ~/ 7;

      labels.add(
        _MonthPosition(month: month, columnIndex: columnIndex),
      );
    }

    final labelHeight =
        (theme.textTheme.bodyMedium?.fontSize ?? 14) * 1.4;

    return SizedBox(
      height: labelHeight,
      child: Stack(
        children: [
          for (final label in labels)
            Positioned(
              left: label.columnIndex *
                  (_heatmapTileSize + _heatmapTileSpacing),
              child: Text(
                '${label.month}月',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels(ThemeData theme) {
    const labels = ['日', '一', '二', '三', '四', '五', '六'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == labels.length - 1 ? 0 : _heatmapTileSpacing,
            ),
            child: SizedBox(
              height: _heatmapTileSize,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    labels[i],
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final weekday = normalized.weekday % 7; // 周日 = 0
    return normalized.subtract(Duration(days: weekday));
  }

  Widget _buildLegend(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '少',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
        const SizedBox(width: 8),
        Row(
          children: List.generate(5, (index) {
            final opacity = 0.15 + index * 0.18;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF4AC26B).withOpacity(opacity),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 8),
        Text(
          '多',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Center(
      child: Text(
        '数据更新于 2 分钟前',
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    this.selectedColor = const Color(0xFF0F4D32),
  });

  final String label;
  final bool isSelected;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isSelected ? selectedColor : Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}

class _MonthPosition {
  const _MonthPosition({
    required this.month,
    required this.columnIndex,
  });

  final int month;
  final int columnIndex;
}
