import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ringotrack/domain/drawing_app_preferences_controller.dart';
import 'package:ringotrack/providers.dart';
import 'package:ringotrack/widgets/ringo_heatmap.dart';
import 'package:ringotrack/domain/usage_analysis.dart';
import 'package:fl_chart/fl_chart.dart';

const double _heatmapTileSize = 13;
const double _heatmapTileSpacing = 3;

enum DashboardTab { overview, perApp, analysis }

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
      backgroundColor: theme.colorScheme.surface,
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
        if (_selectedTab == DashboardTab.analysis)
          Expanded(
            child: _buildAnalysisList(
              theme,
              asyncUsage,
            ),
          )
        else
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
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
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
          IconButton(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings_outlined),
            color: theme.colorScheme.primary,
            tooltip: '设置',
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
    final selectedColor = theme.colorScheme.primary;

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
              _selectedTab = DashboardTab.analysis;
            });
          },
          child: _TabButton(
            label: '分析',
            isSelected: _selectedTab == DashboardTab.analysis,
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

    // 构建 appId -> DisplayName 映射，方便在「按软件」视图展示人类可读名称。
    final prefsAsync = ref.watch(drawingAppPrefsControllerProvider);
    final appDisplayNames = prefsAsync.when(
      data: (prefs) {
        final map = <String, String>{};
        for (final app in prefs.trackedApps) {
          for (final id in app.ids) {
            map[id.value.toLowerCase()] = app.displayName;
          }
        }
        return map;
      },
      loading: () => const <String, String>{},
      error: (_, __) => const <String, String>{},
    );

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

        Widget buildHeatmap(
          Map<DateTime, Duration> totals, {
          bool showMonthLabels = true,
          Widget? placeholder,
        }) {
          return SizedBox(
            width: innerWidth,
            child: Align(
              alignment: Alignment.topCenter,
              child: RingoHeatmap(
                start: start,
                end: end,
                dailyTotals: totals,
                baseColor: theme.colorScheme.primary,
                tileSize: tileSize,
                spacing: spacing,
                showMonthLabels: showMonthLabels,
                showWeekdayLabels: true,
                weekdayLabelWidth: weekdayColumnWidth,
                weekdayLabelGap: gapBetweenWeekdayAndGrid,
                headerToGridSpacing: 24.h,
                monthLabelStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                ),
                weekdayLabelStyle: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 15.sp,
                  color: Colors.black54,
                ),
                emptyPlaceholder: placeholder,
              ),
            ),
          );
        }

        Widget buildEmptyPlaceholder() {
          return Text(
            '开始打开你喜欢的绘画软件，RingoTrack 会在这里记录你的创作小绿砖',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
            textAlign: TextAlign.center,
          );
        }

        final heatmapChild = asyncUsage.when(
          data: (usageByDate) {
            if (usageByDate.isEmpty) {
              return buildHeatmap(
                const {},
                placeholder: buildEmptyPlaceholder(),
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

              return buildHeatmap(totals, placeholder: buildEmptyPlaceholder());
            }

            if (selectedTab == DashboardTab.perApp) {
              final perApp = <String, Map<DateTime, Duration>>{};

              usageByDate.forEach((day, appMap) {
                appMap.forEach((appId, duration) {
                  final byDate =
                      perApp.putIfAbsent(appId, () => <DateTime, Duration>{});
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
                    final displayName =
                        appDisplayNames[appId.toLowerCase()] ?? appId;

                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          buildHeatmap(appDaily, showMonthLabels: true),
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
              heatmapChild,
              SizedBox(height: 24.h),
              _buildLegend(theme),
            ],
          ),
        );
      },
    );
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final weekday = normalized.weekday % 7; // 周日 = 0
    return normalized.subtract(Duration(days: weekday));
  }

  Widget _buildLegend(ThemeData theme) {
    final baseColor = theme.colorScheme.primary;

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
                  color: baseColor.withOpacity(opacity),
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

  Widget _buildAnalysisList(
    ThemeData theme,
    AsyncValue<Map<DateTime, Map<String, Duration>>> asyncUsage,
  ) {
    final prefsAsync = ref.watch(drawingAppPrefsControllerProvider);
    final displayNameMap = prefsAsync.when(
      data: (prefs) {
        final map = <String, String>{};
        for (final app in prefs.trackedApps) {
          for (final id in app.ids) {
            map[id.value.toLowerCase()] = app.displayName;
          }
        }
        return map;
      },
      loading: () => const <String, String>{},
      error: (_, __) => const <String, String>{},
    );

    String displayName(String appId) {
      return displayNameMap[appId.toLowerCase()] ?? appId;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
      child: asyncUsage.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (err, _) => Center(
          child: Text(
            '加载数据出错了',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.redAccent,
            ),
          ),
        ),
        data: (usageByDate) {
          if (usageByDate.isEmpty) {
            return Center(
              child: Text(
                '还没有可分析的绘画时长，先去画两笔吧～',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
            );
          }

          final today = DateTime.now();
          final normalizedToday = DateTime(today.year, today.month, today.day);
          final last30Start =
              normalizedToday.subtract(const Duration(days: 29));
          final weekStart = _weekStartMonday(normalizedToday);
          final weekRangeStart =
              weekStart.subtract(const Duration(days: 7 * 7)); // 向前含 8 周

          final analysis = UsageAnalysis(usageByDate);
          final daily = analysis.dailyTotals(last30Start, normalizedToday);
          final weekly =
              analysis.weeklyTotals(weekRangeStart, normalizedToday);
          final perApp =
              analysis.appTotals(last30Start, normalizedToday);
          final weekdayAvg =
              analysis.weekdayAverages(last30Start, normalizedToday);

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _AnalysisCard(
                title: '最近 30 天趋势',
                subtitle: '日总时长折线',
                child: SizedBox(
                  height: 220.h,
                  child: LineChart(
                    _buildDailyLineChartData(theme, daily),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              _AnalysisCard(
                title: '最近 8 周周总时长',
                subtitle: '按周汇总，周一为起点',
                child: SizedBox(
                  height: 220.h,
                  child: BarChart(
                    _buildWeeklyBarData(theme, weekly),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              _AnalysisCard(
                title: '应用占比',
                subtitle: '最近 30 天各软件总时长占比',
                child: SizedBox(
                  height: 240.h,
                  child: Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          _buildAppPieData(theme, perApp),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final entry in perApp.take(4))
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.h),
                              child: Text(
                                '${displayName(entry.appId)} · ${_formatDuration(entry.total)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              _AnalysisCard(
                title: '星期分布',
                subtitle: '最近 30 天平均到星期几的用时',
                child: SizedBox(
                  height: 220.h,
                  child: BarChart(
                    _buildWeekdayBarData(theme, weekdayAvg),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  LineChartData _buildDailyLineChartData(
    ThemeData theme,
    List<DailyTotal> daily,
  ) {
    final color = theme.colorScheme.primary;
    final spots = <FlSpot>[];
    for (var i = 0; i < daily.length; i++) {
      spots.add(FlSpot(i.toDouble(), _hours(daily[i].total)));
    }

    return LineChartData(
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withOpacity(0.15),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 36,
            getTitlesWidget: (value, _) => Text(
              '${value.toStringAsFixed(0)}h',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: (daily.length / 6).clamp(1, 7).toDouble(),
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= daily.length) return const SizedBox();
              final date = daily[index].date;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${date.month}/${date.day}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    fontSize: 11.sp,
                  ),
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withOpacity(0.12),
          ),
          barWidth: 2.6,
        ),
      ],
    );
  }

  BarChartData _buildWeeklyBarData(
    ThemeData theme,
    List<WeeklyTotal> weekly,
  ) {
    final color = theme.colorScheme.primary;
    final groups = <BarChartGroupData>[];

    for (var i = 0; i < weekly.length; i++) {
      final item = weekly[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: _hours(item.total),
              color: color,
              width: 16,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    return BarChartData(
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: 2,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withOpacity(0.15),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 2,
            getTitlesWidget: (value, _) => Text(
              '${value.toStringAsFixed(0)}h',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, _) {
              final index = value.toInt();
              if (index < 0 || index >= weekly.length) {
                return const SizedBox();
              }
              final date = weekly[index].weekStart;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${date.month}/${date.day}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    fontSize: 11.sp,
                  ),
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: groups,
      minY: 0,
    );
  }

  PieChartData _buildAppPieData(
    ThemeData theme,
    List<AppTotal> totals,
  ) {
    final colors = [
      theme.colorScheme.primary,
      const Color(0xFF51B8A3),
      const Color(0xFF5D6DFF),
      const Color(0xFFFFB347),
      const Color(0xFF9B6BFF),
    ];

    final top = totals.take(4).toList();
    final others = totals.skip(4);
    final otherTotal = others.fold<Duration>(
      Duration.zero,
      (acc, e) => acc + e.total,
    );
    if (otherTotal > Duration.zero) {
      top.add(AppTotal(appId: '其他', total: otherTotal));
    }

    final sum = top.fold<double>(
      0,
      (acc, e) => acc + e.total.inSeconds.toDouble(),
    );

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < top.length; i++) {
      final entry = top[i];
      final percent =
          sum == 0 ? 0.0 : entry.total.inSeconds.toDouble() / sum;
      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: percent,
          title: '${(percent * 100).toStringAsFixed(0)}%',
          radius: 60.r,
          titleStyle: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return PieChartData(
      sections: sections,
      centerSpaceRadius: 28.r,
      sectionsSpace: 2,
    );
  }

  BarChartData _buildWeekdayBarData(
    ThemeData theme,
    List<WeekdayAverage> data,
  ) {
    final color = theme.colorScheme.primary;
    final labels = ['一', '二', '三', '四', '五', '六', '日'];

    final bars = data.map((e) {
      final idx = e.weekday - 1;
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: _hours(e.average),
            color: color,
            width: 18,
            borderRadius: BorderRadius.circular(2),
          )
        ],
      );
    }).toList();

    return BarChartData(
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withOpacity(0.15),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 40,
            getTitlesWidget: (value, _) => Text(
              '${value.toStringAsFixed(0)}h',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, _) {
              final idx = value.toInt();
              if (idx < 0 || idx >= labels.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  labels[idx],
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: bars,
      minY: 0,
    );
  }

  double _hours(Duration d) => d.inMinutes / 60.0;

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
    required this.selectedColor,
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

DateTime _weekStartMonday(DateTime day) {
  final normalized = DateTime(day.year, day.month, day.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: 4.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE3E3E3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ]
            ],
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}
