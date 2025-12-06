import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/domain/usage_analysis.dart';

void main() {
  group('HourlyUsageAnalysis', () {
    test('hourlyBuckets fills missing hours with zero and keeps order', () {
      final day = DateTime(2025, 1, 1);

      final usageByDateHour = {
        day: {
          9: {'A': const Duration(minutes: 30)},
          11: {
            'A': const Duration(minutes: 10),
            'B': const Duration(minutes: 20),
          },
        },
      };

      final analysis = HourlyUsageAnalysis(usageByDateHour);
      final buckets = analysis.hourlyBuckets(day);

      expect(buckets.length, 24);

      // 9 点
      final h9 = buckets[9];
      expect(h9.hourIndex, 9);
      expect(h9.total.inMinutes, 30);
      expect(h9.perApp['A']!.inMinutes, 30);

      // 10 点应为 0
      final h10 = buckets[10];
      expect(h10.hourIndex, 10);
      expect(h10.total, Duration.zero);
      expect(h10.perApp.isEmpty, isTrue);

      // 11 点有两款 app
      final h11 = buckets[11];
      expect(h11.hourIndex, 11);
      expect(h11.total.inMinutes, 30);
      expect(h11.perApp['A']!.inMinutes, 10);
      expect(h11.perApp['B']!.inMinutes, 20);
    });
  });
}
