import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/domain/app_database.dart';
import 'package:ringotrack/domain/usage_repository.dart';

void main() {
  group('SqliteUsageRepository', () {
    late AppDatabase db;
    late UsageRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = SqliteUsageRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('mergeUsage accumulates durations for same day and app', () async {
      final day = DateTime(2025, 1, 1);

      await repo.mergeUsage({
        day: {'Photoshop.exe': const Duration(minutes: 10)},
      });

      await repo.mergeUsage({
        day: {'Photoshop.exe': const Duration(minutes: 20)},
      });

      final range = await repo.loadRange(
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 1),
      );

      expect(range.containsKey(day), isTrue);
      final duration = range[day]!['Photoshop.exe']!;
      expect(duration.inMinutes, 30);
    });

    test('loadRange returns only days within inclusive range', () async {
      final day1 = DateTime(2025, 1, 1);
      final day2 = DateTime(2025, 1, 2);
      final day3 = DateTime(2025, 1, 3);

      await repo.mergeUsage({
        day1: {'Photoshop.exe': const Duration(minutes: 10)},
        day2: {'Photoshop.exe': const Duration(minutes: 20)},
        day3: {'Photoshop.exe': const Duration(minutes: 30)},
      });

      final range = await repo.loadRange(
        DateTime(2025, 1, 2),
        DateTime(2025, 1, 3),
      );

      expect(range.containsKey(day1), isFalse);
      expect(range.containsKey(day2), isTrue);
      expect(range.containsKey(day3), isTrue);
    });

    test('deleteByAppId removes only the target app', () async {
      final day = DateTime(2025, 1, 1);

      await repo.mergeUsage({
        day: {
          'Photoshop.exe': const Duration(minutes: 10),
          'ClipStudio': const Duration(minutes: 20),
        },
      });

      await repo.deleteByAppId('Photoshop.exe');

      final range = await repo.loadRange(
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 1),
      );

      expect(range[day]!.containsKey('Photoshop.exe'), isFalse);
      expect(range[day]!['ClipStudio']!.inMinutes, 20);
    });

    test('deleteByDateRange removes all apps within range', () async {
      final d1 = DateTime(2025, 1, 1);
      final d2 = DateTime(2025, 1, 2);
      final d3 = DateTime(2025, 1, 3);

      await repo.mergeUsage({
        d1: {'App': const Duration(minutes: 10)},
        d2: {'App': const Duration(minutes: 20)},
        d3: {'App': const Duration(minutes: 30)},
      });

      await repo.deleteByDateRange(d1, d2);

      final range = await repo.loadRange(d1, d3);

      expect(range.containsKey(d1), isFalse);
      expect(range.containsKey(d2), isFalse);
      expect(range.containsKey(d3), isTrue);
    });

    test('clearAll removes every record', () async {
      final day = DateTime(2025, 1, 1);

      await repo.mergeUsage({
        day: {'App': const Duration(minutes: 10)},
      });

      await repo.clearAll();

      final range = await repo.loadRange(
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 1),
      );

      expect(range.isEmpty, isTrue);
    });
  });
}
