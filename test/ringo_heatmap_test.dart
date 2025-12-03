import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/widgets/ringo_heatmap.dart';

void main() {
  group('RingoHeatmap', () {
    testWidgets('renders a tile for each day in range',
        (WidgetTester tester) async {
      final start = DateTime(2025, 1, 1);
      final end = DateTime(2025, 1, 3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RingoHeatmap(
              start: start,
              end: end,
              dailyTotals: const {},
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('day-2025-01-01')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-2025-01-02')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-2025-01-03')), findsOneWidget);
    });

    testWidgets('applies color levels based on duration',
        (WidgetTester tester) async {
      final start = DateTime(2025, 1, 1);
      final end = DateTime(2025, 1, 3);

      final dailyTotals = <DateTime, Duration>{
        DateTime(2025, 1, 1): Duration.zero,
        DateTime(2025, 1, 2): const Duration(minutes: 30),
        DateTime(2025, 1, 3): const Duration(minutes: 120),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RingoHeatmap(
              start: start,
              end: end,
              dailyTotals: dailyTotals,
            ),
          ),
        ),
      );

      final tile1 = tester.widget<Container>(
        find.byKey(const ValueKey('day-2025-01-01')),
      );
      final tile2 = tester.widget<Container>(
        find.byKey(const ValueKey('day-2025-01-02')),
      );
      final tile3 = tester.widget<Container>(
        find.byKey(const ValueKey('day-2025-01-03')),
      );

      expect(tile1.color, equals(Colors.green.withOpacity(0.05)));
      expect(tile2.color, equals(Colors.green.withOpacity(0.4)));
      expect(tile3.color, equals(Colors.green.withOpacity(0.7)));
    });
  });
}

