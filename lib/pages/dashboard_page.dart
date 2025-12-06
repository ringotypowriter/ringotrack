import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ringotrack/domain/drawing_app_preferences_controller.dart';
import 'package:ringotrack/providers.dart';
import 'package:ringotrack/widgets/ringo_heatmap.dart';
import 'package:ringotrack/domain/usage_analysis.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ringotrack/widgets/ringo_hourly_line_heatmap.dart';
import 'package:ringotrack/widgets/heatmap_color_scale.dart';
import 'dart:io' show Platform;

const double _heatmapTileSize = 13;
const double _heatmapTileSpacing = 3;
const double _dashboardCardRadius = 12;
const double _dashboardElementRadius = 4;

enum DashboardTab { overview, perApp, analysis }

class HourlySelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDay(DateTime day) {
    state = day;
  }
}

final hourlySelectedDayProvider = NotifierProvider<HourlySelectedDay, DateTime>(
  HourlySelectedDay.new,
);

final hourlyUsageByDayProvider =
    StreamProvider.autoDispose.family<Map<int, Map<String, Duration>>, DateTime>(
      (ref, day) async* {
        final repo = ref.watch(usageRepositoryProvider);
        final service = ref.watch(usageServiceProvider);
        final normalizedDay = _normalizeDayDashboard(day);

        // 初始：从数据库加载该日的小时级用时分布
        final initial = await repo.loadHourlyRange(normalizedDay, normalizedDay);
        final initialForDay = initial[normalizedDay] ?? const <int, Map<String, Duration>>{};

        Map<int, Map<String, Duration>> current = initialForDay.map(
          (hour, perApp) => MapEntry(hour, Map<String, Duration>.from(perApp)),
        );

        yield current;

        // 后续：监听 UsageService 的小时级增量流，增量合并到当日数据
        await for (final delta in service.hourlyDeltaStream) {
          final dayDelta = delta[normalizedDay];
          if (dayDelta == null || dayDelta.isEmpty) {
            continue;
          }

          dayDelta.forEach((hour, perAppDelta) {
            final perApp = current.putIfAbsent(
              hour,
              () => <String, Duration>{},
            );
            perAppDelta.forEach((appId, duration) {
              perApp[appId] =
                  (perApp[appId] ?? Duration.zero) + duration;
            });
          });

          // 输出一份深拷贝，避免外部修改内部状态
          yield current.map(
            (hour, perApp) => MapEntry(
              hour,
              Map<String, Duration>.from(perApp),
            ),
          );
        }
      },
    );

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
    final range = ref.watch(heatmapRangeProvider);
    final start = range.start;
    final end = range.end;

    final asyncUsage = ref.watch(yearlyUsageByDateProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      backgroundColor: Platform.isMacOS ? Colors.transparent : Colors.grey[100],
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1440.w, maxHeight: 900.h),
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
                            _buildSummaryRow(context, theme, metricsAsync),
                            const SizedBox(height: 40),
                            _buildTabs(theme),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _selectedTab == DashboardTab.analysis
                                  ? _buildAnalysisList(theme, asyncUsage)
                                  : _buildHeatmapShell(
                                      theme,
                                      start: start,
                                      end: end,
                                      asyncUsage: asyncUsage,
                                      selectedTab: _selectedTab,
                                    ),
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
    );
  }

  Widget _buildTopBar(BuildContext context, ThemeData theme) {
    final horizontal = 64.w;
    final topPadding = Platform.isMacOS ? 40.h : 18.h;
    final bottomPadding = Platform.isMacOS ? 24.h : 18.h;

    return Container(
      color: Platform.isMacOS ? Colors.transparent : Colors.white,
      padding: EdgeInsets.fromLTRB(
        horizontal,
        topPadding,
        horizontal,
        bottomPadding,
      ),
      child: Row(
        children: [
          if (!Platform.isMacOS) ...[
            Container(
              width: 10.r,
              height: 10.r,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            '仪表盘',
            style: (Platform.isMacOS
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.titleMedium)
                ?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
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
    BuildContext context,
    ThemeData theme,
    AsyncValue<DashboardMetrics> metricsAsync,
  ) {
    final titles = ['今日时长', '本周时长', '本月时长', '连续天数'];
    final icons = [
      Icons.today_outlined,
      Icons.view_week_outlined,
      Icons.calendar_month_outlined,
      Icons.local_fire_department_outlined,
    ];

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
        error: (error, stackTrace) => '—',
      );
    }

    return Row(
      children: [
        for (var i = 0; i < titles.length; i++) ...[
          Expanded(
            child: _HoverCard(
              height: 120.h,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
              subtleShadow: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        icons[i],
                        size: 18.r,
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        titles[i],
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (i == 0)
                        IconButton(
                          onPressed: () => context.push('/clock'),
                          icon: const Icon(Icons.fullscreen),
                          tooltip: '全屏',
                          splashRadius: 18.r,
                          iconSize: 18.r,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        valueFor(i),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
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
      error: (error, stackTrace) => const <String, String>{},
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

        if (selectedTab == DashboardTab.perApp) {
          final perAppList = asyncUsage.when(
            data: (usageByDate) {
              if (usageByDate.isEmpty) {
                return buildHeatmap(
                  const {},
                  placeholder: buildEmptyPlaceholder(),
                );
              }

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
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  32.h,
                  horizontalPadding,
                  24.h,
                ),
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
              borderRadius: BorderRadius.circular(_dashboardCardRadius),
              border: Border.all(color: const Color(0xFFE3E3E3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: perAppList),
                SizedBox(height: 8.h),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    24.h,
                  ),
                  child: _buildLegend(theme),
                ),
              ],
            ),
          );
        }

        // Overview tab：月历热力图 + 日内线性热力图，共用一个 legend。
        final calendarHeatmap = asyncUsage.when(
          data: (usageByDate) {
            if (usageByDate.isEmpty) {
              return buildHeatmap(
                const {},
                placeholder: buildEmptyPlaceholder(),
              );
            }

            final totals = <DateTime, Duration>{};
            usageByDate.forEach((day, perApp) {
              totals[day] = perApp.values.fold(Duration.zero, (a, b) => a + b);
            });

            return buildHeatmap(totals, placeholder: buildEmptyPlaceholder());
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

        final selectedDay = ref.watch(hourlySelectedDayProvider);
        final hourlyAsync = ref.watch(hourlyUsageByDayProvider(selectedDay));
        final normalizedSelected = _normalizeDayDashboard(selectedDay);
        final today = _normalizeDayDashboard(DateTime.now());
        final maxDay = normalizedEnd.isBefore(today) ? normalizedEnd : today;
        final minDay = normalizedStart;

        bool canGoPrev = normalizedSelected.isAfter(minDay);
        bool canGoNext = normalizedSelected.isBefore(maxDay);

        void shiftDay(int delta) {
          final next = _normalizeDayDashboard(
            normalizedSelected.add(Duration(days: delta)),
          );
          if (next.isBefore(minDay) || next.isAfter(maxDay)) return;
          ref.read(hourlySelectedDayProvider.notifier).setDay(next);
        }

        return Container(
          key: const ValueKey('dashboard-heatmap-shell'),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_dashboardCardRadius),
            border: Border.all(color: const Color(0xFFE3E3E3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  32.h,
                  horizontalPadding,
                  16.h,
                ),
                child: calendarHeatmap,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Divider(height: 32.h, thickness: 1),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  12.h,
                ),
                child: Row(
                  children: [
                    SizedBox(width: 16.w),
                    _HoverIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      enabled: canGoPrev,
                      onTap: () => shiftDay(-1),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      _formatDayLabel(normalizedSelected, today),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    _HoverIconButton(
                      icon: Icons.arrow_forward_ios_rounded,
                      enabled: canGoNext,
                      onTap: () => shiftDay(1),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  8.h,
                ),
                child: hourlyAsync.when(
                  data: (hourly) {
                    final totals = <int, Duration>{};
                    hourly.forEach((hour, perApp) {
                      totals[hour] = perApp.values.fold(
                        Duration.zero,
                        (a, b) => a + b,
                      );
                    });

                    if (totals.isEmpty) {
                      return Center(
                        child: Text(
                          '这一天还没有记录到绘画时间',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      );
                    }

                    return RingoHourlyLineHeatmap(
                      hourlyTotals: totals,
                      baseColor: theme.colorScheme.primary,
                      emptyColor: const Color(0xFFE3E3E3),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (error, stack) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Text(
                      '日内分布加载失败',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  4.h,
                  horizontalPadding,
                  24.h,
                ),
                child: _buildLegend(theme),
              ),
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
    final legendColors = HeatmapColorScale.legendColors(baseColor);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '少',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
        SizedBox(width: 8.w),
        Row(
          children: legendColors
              .map(
                (color) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3.w),
                  child: Container(
                    width: 10.r,
                    height: 10.r,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius:
                          BorderRadius.circular(_dashboardElementRadius),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
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
      error: (error, stackTrace) => const <String, String>{},
    );

    String displayName(String appId) {
      return displayNameMap[appId.toLowerCase()] ?? appId;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_dashboardCardRadius),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
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
          final last30Start = normalizedToday.subtract(
            const Duration(days: 29),
          );
          final weekStart = _weekStartMonday(normalizedToday);
          final weekRangeStart = weekStart.subtract(
            const Duration(days: 7 * 7),
          ); // 向前含 8 周

          final analysis = UsageAnalysis(usageByDate);
          final daily = analysis.dailyTotals(last30Start, normalizedToday);
          final weekly = analysis.weeklyTotals(weekRangeStart, normalizedToday);
          final perApp = analysis.appTotals(last30Start, normalizedToday);
          final weekdayAvg = analysis.weekdayAverages(
            last30Start,
            normalizedToday,
          );

          return ListView(
            padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
            children: [
              _AnalysisCard(
                title: '最近 30 天趋势',
                subtitle: '日总时长折线',
                child: SizedBox(
                  height: 220.h,
                  child: LineChart(_buildDailyLineChartData(theme, daily)),
                ),
              ),
              SizedBox(height: 16.h),
              _AnalysisCard(
                title: '最近 8 周周总时长',
                subtitle: '按周汇总，周一为起点',
                child: SizedBox(
                  height: 220.h,
                  child: BarChart(_buildWeeklyBarData(theme, weekly)),
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
                        child: PieChart(_buildAppPieData(theme, perApp)),
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
                  child: BarChart(_buildWeekdayBarData(theme, weekdayAvg)),
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
    final maxMinutes = daily.isEmpty
        ? 0.0
        : daily
            .map((e) => e.total.inSeconds / 60.0)
            .fold<double>(0.0, (prev, m) => m > prev ? m : prev);
    final useMinutes = maxMinutes > 0 && maxMinutes < 60;
    final interval = useMinutes ? (maxMinutes <= 30 ? 10.0 : 20.0) : 1.0;
    final maxValue = useMinutes ? maxMinutes : maxMinutes / 60.0;
    final maxY = maxValue <= 0
        ? interval
        : ((maxValue / interval).ceil() * interval);

    final spots = <FlSpot>[
      for (var i = 0; i < daily.length; i++)
        FlSpot(
          i.toDouble(),
          useMinutes
              ? daily[i].total.inSeconds / 60.0
              : _hours(daily[i].total),
        ),
    ];

    return LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots
                .map((spot) {
                  final index = spot.x.round();
                  if (index < 0 || index >= daily.length) {
                    return null;
                  }
                  final item = daily[index];
                  final date = item.date;
                  final dateLabel = '${date.month}/${date.day}';
                  final durationLabel = _formatDuration(item.total);
                  final style =
                      theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ) ??
                      const TextStyle(color: Colors.white, fontSize: 11);
                  return LineTooltipItem('$dateLabel\n$durationLabel', style);
                })
                .whereType<LineTooltipItem>()
                .toList();
          },
        ),
      ),
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: interval,
            reservedSize: 36,
            getTitlesWidget: (value, _) => Text(
              useMinutes
                  ? '${value.toStringAsFixed(0)}m'
                  : '${value.toStringAsFixed(0)}h',
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
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.12),
          ),
          barWidth: 2.6,
        ),
      ],
    );
  }

  BarChartData _buildWeeklyBarData(ThemeData theme, List<WeeklyTotal> weekly) {
    final color = theme.colorScheme.primary;
    final maxMinutes = weekly.isEmpty
        ? 0.0
        : weekly
            .map((e) => e.total.inSeconds / 60.0)
            .fold<double>(0.0, (prev, m) => m > prev ? m : prev);
    final useMinutes = maxMinutes > 0 && maxMinutes < 60;
    final interval = useMinutes ? (maxMinutes <= 30 ? 10.0 : 20.0) : 2.0;
    final maxValue = useMinutes ? maxMinutes : maxMinutes / 60.0;
    final maxY = maxValue <= 0
        ? interval
        : ((maxValue / interval).ceil() * interval);
    final groups = <BarChartGroupData>[];

    for (var i = 0; i < weekly.length; i++) {
      final total = weekly[i].total;
      final value =
          useMinutes ? total.inSeconds / 60.0 : _hours(weekly[i].total);
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: color,
              width: 16,
              borderRadius: BorderRadius.circular(_dashboardElementRadius),
            ),
          ],
        ),
      );
    }

    return BarChartData(
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            if (groupIndex < 0 || groupIndex >= weekly.length) {
              return null;
            }
            final item = weekly[groupIndex];
            final date = item.weekStart;
            final dateLabel = '${date.month}/${date.day}';
            final durationLabel = _formatDuration(item.total);
            final style =
                theme.textTheme.bodySmall?.copyWith(color: Colors.white) ??
                const TextStyle(color: Colors.white, fontSize: 11);
            return BarTooltipItem('$dateLabel\n$durationLabel', style);
          },
        ),
      ),
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: interval,
            getTitlesWidget: (value, _) => Text(
              useMinutes
                  ? '${value.toStringAsFixed(0)}m'
                  : '${value.toStringAsFixed(0)}h',
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
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      barGroups: groups,
      minY: 0,
      maxY: maxY,
    );
  }

  PieChartData _buildAppPieData(ThemeData theme, List<AppTotal> totals) {
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
      final percent = sum == 0 ? 0.0 : entry.total.inSeconds.toDouble() / sum;
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
    final maxMinutes = data.isEmpty
        ? 0.0
        : data
              .map((e) => e.average.inSeconds / 60.0)
              .fold<double>(0.0, (prev, m) => m > prev ? m : prev);
    final useMinutes = maxMinutes > 0 && maxMinutes < 60;
    final interval = useMinutes ? (maxMinutes <= 30 ? 10.0 : 20.0) : 1.0;
    final maxValue = useMinutes ? maxMinutes : maxMinutes / 60.0;
    final maxY = maxValue <= 0
        ? interval
        : ((maxValue / interval).ceil() * interval);
    final labels = ['一', '二', '三', '四', '五', '六', '日'];

    final bars = data.map((e) {
      final idx = e.weekday - 1;
      final value = useMinutes ? e.average.inSeconds / 60.0 : _hours(e.average);
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: value,
            color: color,
            width: 18,
            borderRadius: BorderRadius.circular(_dashboardElementRadius),
          ),
        ],
      );
    }).toList();

    return BarChartData(
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final weekdayIndex = group.x.toInt();
            if (weekdayIndex < 0 ||
                weekdayIndex >= labels.length ||
                weekdayIndex >= data.length) {
              return null;
            }
            final avg = data[weekdayIndex].average;
            final weekdayLabel = labels[weekdayIndex];
            final durationLabel = _formatDuration(avg);
            final style =
                theme.textTheme.bodySmall?.copyWith(color: Colors.white) ??
                const TextStyle(color: Colors.white, fontSize: 11);
            return BarTooltipItem('周$weekdayLabel\n$durationLabel', style);
          },
        ),
      ),
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: interval,
            reservedSize: 40,
            getTitlesWidget: (value, _) => Text(
              useMinutes
                  ? '${value.toStringAsFixed(0)}m'
                  : '${value.toStringAsFixed(0)}h',
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
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      barGroups: bars,
      minY: 0,
      maxY: maxY,
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
      error: (error, stackTrace) => '数据加载失败，稍后自动重试',
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

class _TabButton extends StatefulWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.selectedColor,
  });

  final String label;
  final bool isSelected;
  final Color selectedColor;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isSelected = widget.isSelected;

    final Color backgroundColor;
    final Color borderColor;
    final Color textColor;

    if (isSelected) {
      backgroundColor = widget.selectedColor;
      borderColor = widget.selectedColor;
      textColor = Colors.white;
    } else {
      backgroundColor = _hovered
          ? theme.colorScheme.surfaceContainerLow
          : Colors.white;
      borderColor = _hovered
          ? theme.colorScheme.outline.withValues(alpha: 0.6)
          : const Color(0xFFE3E3E3);
      textColor = Colors.black87;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        height: 36.h,
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(_dashboardCardRadius),
          border: Border.all(color: borderColor),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        ),
      ),
    );
  }
}

class _HoverIconButton extends StatefulWidget {
  const _HoverIconButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.enabled ? theme.colorScheme.primary : Colors.black26;

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: EdgeInsets.all(6.r),
          decoration: BoxDecoration(
            color: widget.enabled && _hovered
                ? theme.colorScheme.surfaceContainerLow
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon, size: 18.r, color: color),
        ),
      ),
    );
  }
}

DateTime _weekStartMonday(DateTime day) {
  final normalized = DateTime(day.year, day.month, day.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

DateTime _normalizeDayDashboard(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String _formatDayLabel(DateTime day, DateTime today) {
  final base =
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  if (day == today) return '$base · 今天';
  if (day == today.subtract(const Duration(days: 1))) return '$base · 昨天';
  return base;
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
    return _HoverCard(
      margin: EdgeInsets.only(bottom: 4.h),
      padding: EdgeInsets.all(16.w),
      subtleShadow: true,
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
              ],
            ],
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}

class _HoverCard extends StatefulWidget {
  const _HoverCard({
    required this.child,
    this.height,
    this.padding,
    this.margin,
    this.subtleShadow = false,
  });

  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool subtleShadow;

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseAlpha = widget.subtleShadow ? 0.02 : 0.0;
    final hoverAlpha = widget.subtleShadow ? 0.06 : 0.07;

    final double currentAlpha = _hovered ? hoverAlpha : baseAlpha;
    final List<BoxShadow> shadows = [];
    if (currentAlpha > 0) {
      shadows.add(
        BoxShadow(
          color: Colors.black.withValues(alpha: currentAlpha),
          blurRadius: _hovered ? 18 : 10,
          offset: Offset(0, _hovered ? 8 : 4),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        height: widget.height,
        margin: widget.margin,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_dashboardCardRadius),
          border: Border.all(color: const Color(0xFFE3E3E3)),
          boxShadow: shadows,
        ),
        child: widget.child,
      ),
    );
  }
}
