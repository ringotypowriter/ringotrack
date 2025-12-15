import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(51), // 0.2 opacity
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13), // 0.05 opacity
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedYear,
          isDense: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          icon: Icon(
            Icons.calendar_today,
            color: theme.colorScheme.primary,
            size: 16,
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          dropdownColor: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          elevation: 4,
          underline: Container(),
          onChanged: (int? newYear) {
            if (newYear != null) {
              ref
                  .read(dashboardPreferencesControllerProvider.notifier)
                  .setSelectedYear(newYear);
            }
          },
          items: availableYears.map((year) {
            final isCurrentYear = year == currentYear;
            return DropdownMenuItem<int>(
              value: year,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$year年',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: isCurrentYear
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (isCurrentYear) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(
                          26,
                        ), // 0.1 opacity
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '今年',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(51), // 0.2 opacity
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13), // 0.05 opacity
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateTime>(
          value: focusMonth,
          isDense: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          icon: Icon(
            Icons.calendar_view_month,
            color: theme.colorScheme.primary,
            size: 16,
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          dropdownColor: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          elevation: 4,
          underline: Container(),
          onChanged: (DateTime? newMonth) {
            if (newMonth != null) {
              ref
                  .read(dashboardPreferencesControllerProvider.notifier)
                  .setFocusMonth(newMonth);
            }
          },
          items: availableMonths.map((month) {
            final isCurrentMonth =
                month.year == currentMonth.year &&
                month.month == currentMonth.month;
            return DropdownMenuItem<DateTime>(
              value: month,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${month.year}年${month.month}月',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: isCurrentMonth
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (isCurrentMonth) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(
                          26,
                        ), // 0.1 opacity
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '本月',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
