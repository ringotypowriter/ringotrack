import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/domain/usage_hourly_backfill.dart';

void main() {
  group('backfillDailyToHourly', () {
    test(
      'today before noon: fills from current hour backwards',
      () {
        final day = DateTime(2025, 1, 1);
        final now = DateTime(2025, 1, 1, 9, 10);

        // 2.5 小时，总共 9000 秒。
        final result = backfillDailyToHourly(
          total: const Duration(minutes: 150),
          day: day,
          now: now,
        );

        // 期望：从 9 点往前填：
        // 9: 3600, 8: 3600, 7: 1800
        expect(result[9]?.inSeconds, 3600);
        expect(result[8]?.inSeconds, 3600);
        expect(result[7]?.inSeconds, 1800);

        // 其他小时应该是 null 或 0。
        for (var h = 0; h < 24; h++) {
          if (h == 7 || h == 8 || h == 9) continue;
          expect(result[h] == null || result[h] == Duration.zero, isTrue);
        }
      },
    );

    test(
      'today after noon: fills from 12:00 to now, then backwards before 12 if needed',
      () {
        final day = DateTime(2025, 1, 1);
        final now = DateTime(2025, 1, 1, 18, 10);

        // 5 小时，总共 18000 秒。
        final result = backfillDailyToHourly(
          total: const Duration(hours: 5),
          day: day,
          now: now,
        );

        // 期望：从 12 点开始往 18 点方向填，刚好用到 16 点。
        expect(result[12]?.inSeconds, 3600);
        expect(result[13]?.inSeconds, 3600);
        expect(result[14]?.inSeconds, 3600);
        expect(result[15]?.inSeconds, 3600);
        expect(result[16]?.inSeconds, 3600);

        // 17、18 点以及 12 点之前都不应该有数据。
        for (var h = 0; h < 24; h++) {
          if (h >= 12 && h <= 16) continue;
          expect(result[h] == null || result[h] == Duration.zero, isTrue);
        }
      },
    );

    test(
      'today after noon: over 12:00-to-now capacity spills backwards before 12',
      () {
        final day = DateTime(2025, 1, 1);
        final now = DateTime(2025, 1, 1, 16, 30);

        // 从 12 点到 16 点共有 5 个整小时桶，最多容纳 5 小时。
        // 这里给 7 小时，预期先填满 12-16 点，再往 11、10 点回填。
        final result = backfillDailyToHourly(
          total: const Duration(hours: 7),
          day: day,
          now: now,
        );

        for (var h = 12; h <= 16; h++) {
          expect(result[h]?.inSeconds, 3600, reason: 'hour $h should be full');
        }
        expect(result[11]?.inSeconds, 3600);
        expect(result[10]?.inSeconds, 3600);
      },
    );

    test(
      'past days: fills from 12:00 to end of day, then backwards before 12',
      () {
        final day = DateTime(2025, 1, 1);
        final now = DateTime(2025, 1, 2, 10, 0); // 任意次日时间

        // 14 小时，总共 50400 秒。
        final result = backfillDailyToHourly(
          total: const Duration(hours: 14),
          day: day,
          now: now,
        );

        // 步骤：
        // 1) 先从 12-23 共 12 个小时填满 12 小时
        for (var h = 12; h <= 23; h++) {
          expect(result[h]?.inSeconds, 3600, reason: 'hour $h should be full');
        }

        // 2) 还剩 2 小时，从 11、10 开始回填
        expect(result[11]?.inSeconds, 3600);
        expect(result[10]?.inSeconds, 3600);

        // 3) 更早的小时不应该被写入
        for (var h = 0; h <= 9; h++) {
          expect(result[h] == null || result[h] == Duration.zero, isTrue);
        }
      },
    );

    test('never assigns more than 3600 seconds to any hour', () {
      final day = DateTime(2025, 1, 1);
      final now = DateTime(2025, 1, 1, 23, 50);

      // 故意给一个极大的时长，超过 24 小时。
      final result = backfillDailyToHourly(
        total: const Duration(hours: 48),
        day: day,
        now: now,
      );

      var totalAssigned = 0;
      for (var h = 0; h < 24; h++) {
        final seconds = result[h]?.inSeconds ?? 0;
        expect(seconds <= 3600, isTrue, reason: 'hour $h overflow');
        totalAssigned += seconds;
      }

      // 一天最多只能分配 24 * 3600 秒。
      expect(totalAssigned, 24 * 3600);
    });
  });
}

