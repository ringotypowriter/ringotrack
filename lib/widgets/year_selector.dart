import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ringotrack/domain/dashboard_preferences.dart';
import 'package:ringotrack/domain/dashboard_preferences_controller.dart';

/// 年份/月份选择器组件
/// 根据热力图模式显示不同的选择器：
/// - 日历年份模式：年份选择器
/// - 滚动12个月模式：月份选择器
class YearSelector extends ConsumerWidget {
  const YearSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(dashboardPreferencesControllerProvider);
    final prefs = prefsAsync.value ?? const DashboardPreferences();

    if (prefs.heatmapRangeMode == HeatmapRangeMode.rolling12Months) {
      return _MonthSelector();
    } else {
      return _YearSelector();
    }
  }
}

/// 年份选择器（日历年份模式使用）
class _YearSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefsAsync = ref.watch(dashboardPreferencesControllerProvider);
    final prefs = prefsAsync.value ?? const DashboardPreferences();
    final currentYear = DateTime.now().year;
    final selectedYear = prefs.selectedYear ?? currentYear;

    // 生成可选的年份列表（从当前年份往前推10年，往后推2年）
    final availableYears =
        List.generate(
            13,
            (index) => currentYear - 10 + index,
          ).where((year) => year >= 2020 && year <= currentYear + 2).toList()
          ..sort((a, b) => b.compareTo(a)); // 降序排列，最新的年份在前面

    Future<void> showPicker() async {
      final picked = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: false,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    '选择年份',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '切换热力图和分析展示的年份',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    height: 320.h, // 固定高度，避免溢出
                    child: ListView.separated(
                      itemCount: availableYears.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1.h, color: const Color(0xFFF0F0F0)),
                      itemBuilder: (ctx, i) {
                        final year = availableYears[i];
                        final active = year == selectedYear;
                        final isCurrent = year == currentYear;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
                          onTap: () => Navigator.of(ctx).pop(year),
                          title: Row(
                            children: [
                              Text(
                                '$year年',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active
                                      ? theme.colorScheme.primary
                                      : Colors.black87,
                                ),
                              ),
                              if (isCurrent) ...[
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withAlpha(
                                      24,
                                    ),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    '今年',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (active)
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 18.r,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (picked != null) {
        ref
            .read(dashboardPreferencesControllerProvider.notifier)
            .setSelectedYear(picked);
      }
    }

    final pillColor = theme.colorScheme.primary;

    return Container(
      height: 40.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE4E4E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10.r,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$selectedYear年',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          SizedBox(width: 12.w),
          GestureDetector(
            onTap: showPicker,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: pillColor.withAlpha(24),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: pillColor.withAlpha(90)),
              ),
              child: Icon(Icons.calendar_today, size: 12.r, color: pillColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// 月份选择器（滚动12个月模式使用）
class _MonthSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefsAsync = ref.watch(dashboardPreferencesControllerProvider);
    final prefs = prefsAsync.value ?? const DashboardPreferences();
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final focusMonth = prefs.focusMonth ?? currentMonth;

    // 生成最近3年的月份列表（36个月）
    final availableMonths = <DateTime>[];
    for (int i = 0; i < 36; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      if (month.year >= now.year - 2) {
        // 限制为最近3年
        availableMonths.add(month);
      }
    }

    Future<void> showPicker() async {
      final picked = await showModalBottomSheet<DateTime>(
        context: context,
        isScrollControlled: false,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    '选择月份',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '选择焦点月份，查看以该月为结束点的12个月数据',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    height: 320.h, // 固定高度，避免溢出
                    child: ListView.separated(
                      itemCount: availableMonths.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1.h, color: const Color(0xFFF0F0F0)),
                      itemBuilder: (ctx, i) {
                        final month = availableMonths[i];
                        final active =
                            month.year == focusMonth.year &&
                            month.month == focusMonth.month;
                        final isCurrent =
                            month.year == currentMonth.year &&
                            month.month == currentMonth.month;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
                          onTap: () => Navigator.of(ctx).pop(month),
                          title: Row(
                            children: [
                              Text(
                                '${month.year}年${month.month}月',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active
                                      ? theme.colorScheme.primary
                                      : Colors.black87,
                                ),
                              ),
                              if (isCurrent) ...[
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withAlpha(
                                      24,
                                    ),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    '本月',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (active)
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 18.r,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (picked != null) {
        ref
            .read(dashboardPreferencesControllerProvider.notifier)
            .setFocusMonth(picked);
      }
    }

    final pillColor = theme.colorScheme.primary;

    return Container(
      height: 40.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE4E4E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10.r,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${focusMonth.year}年${focusMonth.month}月',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          SizedBox(width: 12.w),
          GestureDetector(
            onTap: showPicker,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: pillColor.withAlpha(24),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: pillColor.withAlpha(90)),
              ),
              child: Icon(
                Icons.calendar_view_month,
                size: 12.r,
                color: pillColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
