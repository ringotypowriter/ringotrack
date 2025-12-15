import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/feature/database/services/app_database.dart';

void main() {
  group('AppDatabase hourly migration backfill', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('backfills today before noon from current hour backwards', () async {
      final today = DateTime(2025, 1, 1);
      final now = DateTime(2025, 1, 1, 9, 10);

      // 插入一条「仅有日级」的旧数据。
      await db
          .into(db.dailyUsageEntries)
          .insert(
            DailyUsageEntriesCompanion.insert(
              date: today,
              appId: 'Photoshop.exe',
              durationSeconds: 150 * 60, // 2.5 小时
            ),
          );

      await db.backfillDailyUsageToHourly(now: now);

      final rows =
          await (db.select(db.hourlyUsageEntries)
                ..where((tbl) => tbl.date.equals(today))
                ..where((tbl) => tbl.appId.equals('Photoshop.exe')))
              .get();

      final byHour = {
        for (final row in rows) row.hourIndex: row.durationSeconds,
      };

      // 期望：从 9 点往前填：9:3600, 8:3600, 7:1800。
      expect(byHour[9], 3600);
      expect(byHour[8], 3600);
      expect(byHour[7], 1800);

      // 其他小时为 null 或 0。
      for (var h = 0; h < 24; h++) {
        if (h == 7 || h == 8 || h == 9) continue;
        expect(byHour[h] == null || byHour[h] == 0, isTrue);
      }
    });

    test(
      'backfills today after noon from 12:00 to now, then backwards',
      () async {
        final today = DateTime(2025, 1, 1);
        final now = DateTime(2025, 1, 1, 18, 10);

        await db
            .into(db.dailyUsageEntries)
            .insert(
              DailyUsageEntriesCompanion.insert(
                date: today,
                appId: 'ClipStudio',
                durationSeconds: 5 * 3600,
              ),
            );

        await db.backfillDailyUsageToHourly(now: now);

        final rows =
            await (db.select(db.hourlyUsageEntries)
                  ..where((tbl) => tbl.date.equals(today))
                  ..where((tbl) => tbl.appId.equals('ClipStudio')))
                .get();

        final byHour = {
          for (final row in rows) row.hourIndex: row.durationSeconds,
        };

        // 期望：从 12 点向 18 点回填，刚好用到 16 点。
        expect(byHour[12], 3600);
        expect(byHour[13], 3600);
        expect(byHour[14], 3600);
        expect(byHour[15], 3600);
        expect(byHour[16], 3600);

        for (var h = 0; h < 24; h++) {
          if (h >= 12 && h <= 16) continue;
          expect(byHour[h] == null || byHour[h] == 0, isTrue);
        }
      },
    );

    test(
      'backfills past days from 12:00 to end of day, then backwards',
      () async {
        final day = DateTime(2025, 1, 1);
        final now = DateTime(2025, 1, 2, 10, 0); // 任意次日

        await db
            .into(db.dailyUsageEntries)
            .insert(
              DailyUsageEntriesCompanion.insert(
                date: day,
                appId: 'Krita.exe',
                durationSeconds: 14 * 3600,
              ),
            );

        await db.backfillDailyUsageToHourly(now: now);

        final rows =
            await (db.select(db.hourlyUsageEntries)
                  ..where((tbl) => tbl.date.equals(day))
                  ..where((tbl) => tbl.appId.equals('Krita.exe')))
                .get();

        final byHour = {
          for (final row in rows) row.hourIndex: row.durationSeconds,
        };

        // 先填满 12-23 点。
        for (var h = 12; h <= 23; h++) {
          expect(byHour[h], 3600, reason: 'hour $h should be full');
        }

        // 再填 11、10 点。
        expect(byHour[11], 3600);
        expect(byHour[10], 3600);

        // 0-9 点不应该有记录。
        for (var h = 0; h <= 9; h++) {
          expect(byHour[h] == null || byHour[h] == 0, isTrue);
        }
      },
    );
  });
}
