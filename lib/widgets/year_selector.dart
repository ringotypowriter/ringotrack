import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ringotrack/domain/dashboard_preferences.dart';
import 'package:ringotrack/domain/dashboard_preferences_controller.dart';

/// 年份选择器组件
class YearSelector extends ConsumerWidget {
  const YearSelector({super.key});

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
