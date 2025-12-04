import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/domain/usage_analysis.dart';

void main() {
  group('UsageAnalysis', () {
    test('dailyTotals fills missing days with zero and keeps order', () {
      final usage = {
        DateTime(2025, 1, 1): {'A': const Duration(minutes: 30)},
        DateTime(2025, 1, 3): {'A': const Duration(minutes: 10)},
      };

      final analysis = UsageAnalysis(usage);
      final result = analysis.dailyTotals(
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 3),
      );

      expect(result.length, 3);
      expect(result[0].date, DateTime(2025, 1, 1));
      expect(result[0].total.inMinutes, 30);
      expect(result[1].date, DateTime(2025, 1, 2));
      expect(result[1].total, Duration.zero);
      expect(result[2].date, DateTime(2025, 1, 3));
      expect(result[2].total.inMinutes, 10);
    });

    test('weeklyTotals groups by Monday-start week', () {
      final usage = {
        DateTime(2025, 1, 1): {'A': const Duration(hours: 1)}, // Wed
        DateTime(2025, 1, 6): {'A': const Duration(hours: 2)}, // Mon next week
      };

      final analysis = UsageAnalysis(usage);
      final result = analysis.weeklyTotals(
        DateTime(2024, 12, 30), // Monday
        DateTime(2025, 1, 12),  // Sunday
      );

      expect(result.length, 2);

      expect(result[0].weekStart, DateTime(2024, 12, 30));
      expect(result[0].total.inHours, 1);

      expect(result[1].weekStart, DateTime(2025, 1, 6));
      expect(result[1].total.inHours, 2);
    });

    test('appTotals sums per app across range', () {
      final usage = {
        DateTime(2025, 1, 1): {'A': const Duration(minutes: 30)},
        DateTime(2025, 1, 2): {
          'A': const Duration(minutes: 40),
          'B': const Duration(minutes: 20),
        },
      };

      final analysis = UsageAnalysis(usage);
      final result = analysis.appTotals(
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 2),
      );

      // Expect A total 70, B total 20
      final totalA =
          result.firstWhere((e) => e.appId == 'A').total.inMinutes;
      final totalB =
          result.firstWhere((e) => e.appId == 'B').total.inMinutes;

      expect(totalA, 70);
      expect(totalB, 20);
    });

    test('weekdayAverages divide by calendar day count in range', () {
      final usage = {
        DateTime(2025, 1, 6): {'A': const Duration(hours: 2)}, // Mon
        DateTime(2025, 1, 12): {'A': const Duration(hours: 1)}, // Sun
      };

      final analysis = UsageAnalysis(usage);
      final result = analysis.weekdayAverages(
        DateTime(2025, 1, 6), // Monday
        DateTime(2025, 1, 12), // Sunday
      );

      final monday =
          result.firstWhere((e) => e.weekday == DateTime.monday);
      final sunday =
          result.firstWhere((e) => e.weekday == DateTime.sunday);
      final tuesday =
          result.firstWhere((e) => e.weekday == DateTime.tuesday);

      expect(monday.average.inHours, 2);
      expect(sunday.average.inHours, 1);
      expect(tuesday.average, Duration.zero);
    });
  });
}
