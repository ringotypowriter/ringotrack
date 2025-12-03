import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/domain/usage_repository.dart';

void main() {
  group('UsageRepository', () {
    test('mergeUsage accumulates durations for same day and app', () {
      final repo = UsageRepository();

      final day = DateTime(2025, 1, 1);

      repo.mergeUsage({
        day: {'Photoshop.exe': const Duration(minutes: 10)},
      });

      repo.mergeUsage({
        day: {'Photoshop.exe': const Duration(minutes: 20)},
      });

      final range =
          repo.loadRange(DateTime(2025, 1, 1), DateTime(2025, 1, 1));

      expect(range.containsKey(day), isTrue);
      final duration = range[day]!['Photoshop.exe']!;
      expect(duration.inMinutes, 30);
    });

    test('loadRange returns only days within inclusive range', () {
      final repo = UsageRepository();

      final day1 = DateTime(2025, 1, 1);
      final day2 = DateTime(2025, 1, 2);
      final day3 = DateTime(2025, 1, 3);

      repo.mergeUsage({
        day1: {'Photoshop.exe': const Duration(minutes: 10)},
        day2: {'Photoshop.exe': const Duration(minutes: 20)},
        day3: {'Photoshop.exe': const Duration(minutes: 30)},
      });

      final range =
          repo.loadRange(DateTime(2025, 1, 2), DateTime(2025, 1, 3));

      expect(range.containsKey(day1), isFalse);
      expect(range.containsKey(day2), isTrue);
      expect(range.containsKey(day3), isTrue);
    });
  });
}

