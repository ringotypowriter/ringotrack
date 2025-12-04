import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ringotrack/providers.dart';
import 'package:ringotrack/widgets/ringo_heatmap.dart';

const double _heatmapTileSize = 13;
const double _heatmapTileSpacing = 3;

enum DashboardTab { overview, perApp, group }

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DashboardTab _selectedTab = DashboardTab.overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final today = DateTime.now();
    final end = DateTime(today.year, 12, 31);
    final start = DateTime(today.year, 1, 1);

    final asyncUsage = ref.watch(yearlyUsageByDateProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1440.w, maxHeight: 900.h),
          child: Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(context, theme),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummaryRow(theme, metricsAsync),
                              const SizedBox(height: 40),
                              _buildTabs(theme),
                              const SizedBox(height: 16),
                              _buildHeatmapShell(
                                theme,
                                start: start,
                                end: end,
                                asyncUsage: asyncUsage,
                                selectedTab: _selectedTab,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFooter(theme, metricsAsync),
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

  Widget _buildTopBar(BuildContext context, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 64.w, vertical: 18.h),
      child: Row(
        children: [
          Container(
            width: 10.r,
            height: 10.r,
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
          GestureDetector(
            onTap: () => context.go('/settings'),
            behavior: HitTestBehavior.opaque,
            child: Text('设置', style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    ThemeData theme,
    AsyncValue<DashboardMetrics> metricsAsync,
  ) {
    final titles = ['今日时长', '本周时长', '本月时长', '连续天数'];

    String valueFor(int index) {
      return metricsAsync.when(
        data: (metrics) {
          switch (index) {
            case 0:
              return _formatDuration(metrics.today);
            case 1:
              return _formatDuration(metrics.thisWeek);
            case 2:
              return _formatDuration(metrics.thisMonth);
            case 3:
              return '${metrics.streakDays} 天';
          }
          return '—';
        },
        loading: () => '计算中…',
        error: (_, __) => '—',
      );
    }

    return Row(
      children: [
        for (var i = 0; i < titles.length; i++) ...[
          Expanded(
            child: Container(
              height: 120.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: const Color(0xFFE3E3E3)),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
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
                        valueFor(i),
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
          if (i != titles.length - 1) SizedBox(width: 24.w),
        ],
      ],
    );
  }

  Widget _buildTabs(ThemeData theme) {
    final selectedColor = const Color(0xFF4AC26B);

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedTab = DashboardTab.overview;
            });
          },
          child: _TabButton(
            label: '总览',
            isSelected: _selectedTab == DashboardTab.overview,
            selectedColor: selectedColor,
          ),
        ),
        SizedBox(width: 8.w),
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedTab = DashboardTab.perApp;
            });
          },
          child: _TabButton(
            label: '按软件',
            isSelected: _selectedTab == DashboardTab.perApp,
            selectedColor: selectedColor,
          ),
        ),
        SizedBox(width: 8.w),
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedTab = DashboardTab.group;
            });
          },
          child: _TabButton(
            label: '分组',
            isSelected: _selectedTab == DashboardTab.group,
            selectedColor: selectedColor,
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapShell(
    ThemeData theme, {
    required DateTime start,
    required DateTime end,
    required AsyncValue<Map<DateTime, Map<String, Duration>>> asyncUsage,
    required DashboardTab selectedTab,
  }) {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    final calendarStart = _startOfWeek(normalizedStart);
    final totalDays = normalizedEnd.difference(calendarStart).inDays + 1;
    final weekCount = (totalDays / 7).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = 40.w;
        final innerWidth = constraints.maxWidth - horizontalPadding * 2;

        // 左侧星期列固定宽度，便于计算 heatmap 可用宽度
        final weekdayColumnWidth = 24.w;
        final gapBetweenWeekdayAndGrid = 20.w;

        final baseTileSize = _heatmapTileSize.r;
        final spacing = _heatmapTileSpacing.r;

        final heatmapAvailableWidth =
            innerWidth - weekdayColumnWidth - gapBetweenWeekdayAndGrid;

        var tileSize =
            (heatmapAvailableWidth - (weekCount - 1) * spacing) / weekCount;
        // 基于设计尺寸做一个合理的夹紧，避免过大或过小
        tileSize = tileSize.clamp(baseTileSize * 0.9, baseTileSize * 1.4);

        final gridWidth = weekCount * tileSize + (weekCount - 1) * spacing;

        // 整体（星期列 + 间距 + 网格）在卡片内部水平居中
        final totalHeatmapWidth =
            weekdayColumnWidth + gapBetweenWeekdayAndGrid + gridWidth;
        final leftOffsetWithinInner = ((innerWidth - totalHeatmapWidth) / 2)
            .clamp(0.0, double.infinity);

        // 网格起始位置（相对于卡片内容区域左侧），用于让月份标题与格子列对齐
        final gridStartXWithinContent =
            leftOffsetWithinInner +
            weekdayColumnWidth +
            gapBetweenWeekdayAndGrid;

        final heatmapChild = asyncUsage.when(
          data: (usageByDate) {
            if (usageByDate.isEmpty) {
              return Center(
                child: Text(
                  '开始打开你喜欢的绘画软件，RingoTrack 会在这里记录你的创作小绿砖',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (selectedTab == DashboardTab.overview) {
              final totals = <DateTime, Duration>{};
              usageByDate.forEach((day, perApp) {
                totals[day] = perApp.values.fold(
                  Duration.zero,
                  (a, b) => a + b,
                );
              });

              return SizedBox(
                width: gridWidth,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: RingoHeatmap(
                    start: start,
                    end: end,
                    dailyTotals: totals,
                    baseColor: const Color(0xFF4AC26B),
                    tileSize: tileSize,
                    spacing: spacing,
                  ),
                ),
              );
            }

            if (selectedTab == DashboardTab.perApp) {
              final perApp = <String, Map<DateTime, Duration>>{};

              usageByDate.forEach((day, appMap) {
                appMap.forEach((appId, duration) {
                  final byDate = perApp.putIfAbsent(
                    appId,
                    () => <DateTime, Duration>{},
                  );
                  byDate[day] = (byDate[day] ?? Duration.zero) + duration;
                });
              });

              final appIds = perApp.keys.toList()
                ..sort((a, b) {
                  Duration totalFor(String id) =>
                      perApp[id]!.values.fold(Duration.zero, (x, y) => x + y);

                  return totalFor(b).compareTo(totalFor(a));
                });

              return SizedBox(
                height: 260.h,
                child: ListView.builder(
                  itemCount: appIds.length,
                  itemBuilder: (context, index) {
                    final appId = appIds[index];
                    final appDaily = perApp[appId]!;

                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appId,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWeekdayLabels(
                                theme,
                                tileSize: tileSize,
                                spacing: spacing,
                                columnWidth: weekdayColumnWidth,
                              ),
                              SizedBox(width: gapBetweenWeekdayAndGrid),
                              SizedBox(
                                width: gridWidth,
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: RingoHeatmap(
                                    start: start,
                                    end: end,
                                    dailyTotals: appDaily,
                                    baseColor: const Color(0xFF4AC26B),
                                    tileSize: tileSize,
                                    spacing: spacing,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }

            return Center(
              child: Text(
                '分组视图开发中……',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (error, stack) => Center(
            child: Text(
              '加载数据出错了',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.redAccent,
              ),
            ),
          ),
        );

        return Container(
          key: const ValueKey('dashboard-heatmap-shell'),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: const Color(0xFFE3E3E3)),
          ),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            32.h,
            horizontalPadding,
            24.h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthHeader(
                theme: theme,
                start: start,
                end: end,
                calendarStart: calendarStart,
                weekCount: weekCount,
                tileSize: tileSize,
                spacing: spacing,
                gridStartXWithinContent: gridStartXWithinContent,
              ),
              SizedBox(height: 24.h),
              if (selectedTab == DashboardTab.overview)
                SizedBox(
                  width: innerWidth,
                  child: Padding(
                    padding: EdgeInsets.only(left: leftOffsetWithinInner),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWeekdayLabels(
                          theme,
                          tileSize: tileSize,
                          spacing: spacing,
                          columnWidth: weekdayColumnWidth,
                        ),
                        SizedBox(width: gapBetweenWeekdayAndGrid),
                        SizedBox(width: gridWidth, child: heatmapChild),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  width: innerWidth,
                  child: Padding(
                    padding: EdgeInsets.only(left: leftOffsetWithinInner),
                    child: heatmapChild,
                  ),
                ),
              SizedBox(height: 24.h),
              _buildLegend(theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthHeader({
    required ThemeData theme,
    required DateTime start,
    required DateTime end,
    required DateTime calendarStart,
    required int weekCount,
    required double tileSize,
    required double spacing,
    required double gridStartXWithinContent,
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

      labels.add(_MonthPosition(month: month, columnIndex: columnIndex));
    }

    final labelHeight = ((theme.textTheme.bodyMedium?.fontSize ?? 14).sp) * 1.4;

    return SizedBox(
      height: labelHeight,
      child: Stack(
        children: [
          for (final label in labels)
            Positioned(
              left:
                  gridStartXWithinContent +
                  label.columnIndex * (tileSize + spacing),
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

  Widget _buildWeekdayLabels(
    ThemeData theme, {
    required double tileSize,
    required double spacing,
    required double columnWidth,
  }) {
    const labels = ['日', '一', '二', '三', '四', '五', '六'];

    return SizedBox(
      width: columnWidth,
      child: Column(
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
                    child: Text(
                      labels[i],
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 15.sp,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
        SizedBox(width: 8.w),
        Row(
          children: List.generate(5, (index) {
            final opacity = 0.15 + index * 0.18;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 3.w),
              child: Container(
                width: 10.r,
                height: 10.r,
                decoration: BoxDecoration(
                  color: const Color(0xFF4AC26B).withOpacity(opacity),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        SizedBox(width: 8.w),
        Text(
          '多',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildFooter(
    ThemeData theme,
    AsyncValue<DashboardMetrics> metricsAsync,
  ) {
    final text = metricsAsync.when(
      data: (metrics) => '数据更新于 ${_formatLastUpdated(metrics.lastUpdatedAt)}',
      loading: () => '数据更新中…',
      error: (_, __) => '数据加载失败，稍后自动重试',
    );

    return Center(
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.black54,
          fontSize: theme.textTheme.bodySmall?.fontSize?.sp,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  String _formatLastUpdated(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 30) return '刚刚';
    if (diff.inMinutes < 1) return '${diff.inSeconds} 秒前';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';

    String twoDigits(int v) => v.toString().padLeft(2, '0');
    return '${timestamp.month}月${timestamp.day}日 ${twoDigits(timestamp.hour)}:${twoDigits(timestamp.minute)}';
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    this.selectedColor = const Color(0xFF4AC26B),
  });

  final String label;
  final bool isSelected;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 36.h,
      padding: EdgeInsets.symmetric(horizontal: 24.w),
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
  const _MonthPosition({required this.month, required this.columnIndex});

  final int month;
  final int columnIndex;
}
