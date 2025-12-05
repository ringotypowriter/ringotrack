import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/widgets/ringo_heatmap.dart';

void main() {
  Color _colorForDay(WidgetTester tester, DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    final key = ValueKey('day-$y-$m-$d');
    final container = tester.widget<Container>(find.byKey(key));
    final color = container.color;
    expect(color, isNotNull, reason: 'Tile color should not be null');
    return color!;
  }

  group('RingoHeatmap color intensity', () {
    testWidgets('uses emptyColor for zero-usage days', (tester) async {
      final start = DateTime(2025, 1, 1);
      final end = DateTime(2025, 1, 3);

      // 只在 1 月 2 日有记录，1 日应被视为 0 分钟。
      final dailyTotals = <DateTime, Duration>{
        DateTime(2025, 1, 2): const Duration(minutes: 60),
      };

      const empty = Color(0xFFCCCCCC);
      const base = Colors.green;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RingoHeatmap(
              start: start,
              end: end,
              dailyTotals: dailyTotals,
              baseColor: base,
              emptyColor: empty,
            ),
          ),
        ),
      );

      final zeroDayColor = _colorForDay(tester, DateTime(2025, 1, 1));
      final nonZeroDayColor = _colorForDay(tester, DateTime(2025, 1, 2));

      expect(zeroDayColor, empty);
      expect(nonZeroDayColor, isNot(equals(empty)));
    });

    testWidgets('day with sub-minute usage still gets non-empty color', (
      tester,
    ) async {
      final start = DateTime(2025, 1, 1);
      final end = DateTime(2025, 1, 1);

      final dailyTotals = <DateTime, Duration>{
        DateTime(2025, 1, 1): const Duration(seconds: 10),
      };

      const empty = Color(0xFFCCCCCC);
      const base = Colors.green;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RingoHeatmap(
              start: start,
              end: end,
              dailyTotals: dailyTotals,
              baseColor: base,
              emptyColor: empty,
            ),
          ),
        ),
      );

      final color = _colorForDay(tester, DateTime(2025, 1, 1));
      expect(color, isNot(equals(empty)));
      expect(color.opacity, greaterThan(0));
    });

    testWidgets(
      'day with >5h always has at least half opacity even when average is high',
      (tester) async {
        final start = DateTime(2025, 1, 1);
        final end = DateTime(2025, 1, 5);

        // 四天 10 小时 + 一天 5 小时，确保平均值本身很高，
        // 仍然要求 5h 那天至少达到 0.5 的深度。
        final dailyTotals = <DateTime, Duration>{
          DateTime(2025, 1, 1): const Duration(hours: 10),
          DateTime(2025, 1, 2): const Duration(hours: 10),
          DateTime(2025, 1, 3): const Duration(hours: 10),
          DateTime(2025, 1, 4): const Duration(hours: 10),
          DateTime(2025, 1, 5): const Duration(hours: 5),
        };

        const base = Colors.green;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RingoHeatmap(
                start: start,
                end: end,
                dailyTotals: dailyTotals,
                baseColor: base,
              ),
            ),
          ),
        );

        final fiveHourColor = _colorForDay(tester, DateTime(2025, 1, 5));
        expect(fiveHourColor.opacity, greaterThanOrEqualTo(0.5));
      },
    );

    testWidgets(
      'day with about 2x the average usage is noticeably deeper than near-average day',
      (tester) async {
        final start = DateTime(2025, 1, 1);
        final end = DateTime(2025, 1, 4);

        // 三天各 1 小时 + 一天 3 小时，
        // 非零平均为 1.5 小时，最后一天约为 2x 平均。
        final dailyTotals = <DateTime, Duration>{
          DateTime(2025, 1, 1): const Duration(hours: 1),
          DateTime(2025, 1, 2): const Duration(hours: 1),
          DateTime(2025, 1, 3): const Duration(hours: 1),
          DateTime(2025, 1, 4): const Duration(hours: 3),
        };

        const base = Colors.green;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RingoHeatmap(
                start: start,
                end: end,
                dailyTotals: dailyTotals,
                baseColor: base,
              ),
            ),
          ),
        );

        final nearAverageColor = _colorForDay(tester, DateTime(2025, 1, 1));
        final highRatioColor = _colorForDay(tester, DateTime(2025, 1, 4));

        expect(highRatioColor.opacity, greaterThan(nearAverageColor.opacity));
      },
    );
  });
}
