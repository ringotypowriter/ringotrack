import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:ringotrack/domain/usage_hourly_backfill.dart';

part 'app_database.g.dart';

class DailyUsageEntries extends Table {
  /// 归一化到当天 00:00 的本地日期
  DateTimeColumn get date => dateTime()();

  /// AppId：Windows 下为 exe 名，macOS 下为 bundleId
  TextColumn get appId => text()();

  /// 当天该 app 的总使用时长，单位：秒
  IntColumn get durationSeconds => integer()();

  @override
  Set<Column<Object>> get primaryKey => {date, appId};
}

class HourlyUsageEntries extends Table {
  /// 归一化到当天 00:00 的本地日期
  DateTimeColumn get date => dateTime()();

  /// 当天的第几个小时（0-23）
  IntColumn get hourIndex => integer()();

  /// AppId：Windows 下为 exe 名，macOS 下为 bundleId
  TextColumn get appId => text()();

  /// 该小时内该 app 的总使用时长，单位：秒
  IntColumn get durationSeconds => integer()();

  @override
  Set<Column<Object>> get primaryKey => {date, hourIndex, appId};
}

@DriftDatabase(tables: [DailyUsageEntries, HourlyUsageEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          // 新版本引入了小时级 usage 表，并基于旧的日级数据进行回填。
          await m.createTable(hourlyUsageEntries);
          await backfillDailyUsageToHourly(now: DateTime.now());
        }
      },
    );
  }

  DateTime _normalizeDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 基于现有的 DailyUsageEntries，将「按日 + App」的旧版本数据回填为
  /// 「按日 + 小时 + App」的小时表数据。
  ///
  /// 该方法会遵循 [backfillDailyToHourly] 的规则：
  /// - 单个小时桶最多 3600 秒；
  /// - 今天的数据会根据当前时间分配到不同小时；
  /// - 往日数据以中午 12 点为中心向前后填充。
  Future<void> backfillDailyUsageToHourly({required DateTime now}) async {
    final rows = await select(dailyUsageEntries).get();
    if (rows.isEmpty) {
      return;
    }

    await batch((batch) {
      for (final row in rows) {
        final total = Duration(seconds: row.durationSeconds);
        final buckets = backfillDailyToHourly(
          total: total,
          day: _normalizeDay(row.date),
          now: now,
        );

        if (buckets.isEmpty) {
          continue;
        }

        final inserts = buckets.entries.map(
          (entry) => HourlyUsageEntriesCompanion.insert(
            date: _normalizeDay(row.date),
            hourIndex: entry.key,
            appId: row.appId,
            durationSeconds: entry.value.inSeconds,
          ),
        );

        batch.insertAll(
          hourlyUsageEntries,
          inserts.toList(growable: false),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// 将增量 usage 合并到数据库里（按天 + appId 叠加时长）
  Future<void> mergeUsage(Map<DateTime, Map<String, Duration>> delta) async {
    if (delta.isEmpty) return;

    await transaction(() async {
      for (final entry in delta.entries) {
        final day = _normalizeDay(entry.key);
        for (final appEntry in entry.value.entries) {
          final appId = appEntry.key;
          final seconds = appEntry.value.inSeconds;
          if (seconds <= 0) continue;

          await customInsert(
            'INSERT INTO daily_usage_entries (date, app_id, duration_seconds) '
            'VALUES (?1, ?2, ?3) '
            'ON CONFLICT(date, app_id) DO UPDATE SET '
            'duration_seconds = duration_seconds + excluded.duration_seconds',
            variables: [
              Variable<DateTime>(day),
              Variable<String>(appId),
              Variable<int>(seconds),
            ],
            updates: {dailyUsageEntries},
          );
        }
      }
    });
  }

  /// 按日期范围加载使用时长（精确到日 + App）
  Future<Map<DateTime, Map<String, Duration>>> loadRange(
    DateTime start,
    DateTime end,
  ) async {
    final startDay = _normalizeDay(start);
    final endDay = _normalizeDay(end);

    final rows = await (select(
      dailyUsageEntries,
    )..where((tbl) => tbl.date.isBetweenValues(startDay, endDay))).get();

    final result = <DateTime, Map<String, Duration>>{};
    for (final row in rows) {
      final day = _normalizeDay(row.date);
      final perApp = result.putIfAbsent(day, () => {});
      perApp[row.appId] =
          (perApp[row.appId] ?? Duration.zero) +
          Duration(seconds: row.durationSeconds);
    }
    return result;
  }

  /// 将小时级增量 usage 合并到数据库里（按日 + 小时 + appId 叠加时长）。
  Future<void> mergeHourlyUsage(
    Map<DateTime, Map<int, Map<String, Duration>>> delta,
  ) async {
    if (delta.isEmpty) return;

    await transaction(() async {
      for (final dayEntry in delta.entries) {
        final day = _normalizeDay(dayEntry.key);
        for (final hourEntry in dayEntry.value.entries) {
          final hourIndex = hourEntry.key;
          for (final appEntry in hourEntry.value.entries) {
            final appId = appEntry.key;
            final seconds = appEntry.value.inSeconds;
            if (seconds <= 0) continue;

            await customInsert(
              'INSERT INTO hourly_usage_entries (date, hour_index, app_id, duration_seconds) '
              'VALUES (?1, ?2, ?3, ?4) '
              'ON CONFLICT(date, hour_index, app_id) DO UPDATE SET '
              'duration_seconds = duration_seconds + excluded.duration_seconds',
              variables: [
                Variable<DateTime>(day),
                Variable<int>(hourIndex),
                Variable<String>(appId),
                Variable<int>(seconds),
              ],
              updates: {hourlyUsageEntries},
            );
          }
        }
      }
    });
  }

  /// 按日期范围加载小时级使用时长（精确到：日 + 小时 + App）。
  Future<Map<DateTime, Map<int, Map<String, Duration>>>> loadHourlyRange(
    DateTime start,
    DateTime end,
  ) async {
    final startDay = _normalizeDay(start);
    final endDay = _normalizeDay(end);

    final rows = await (select(
      hourlyUsageEntries,
    )..where((tbl) => tbl.date.isBetweenValues(startDay, endDay))).get();

    final result = <DateTime, Map<int, Map<String, Duration>>>{};
    for (final row in rows) {
      final day = _normalizeDay(row.date);
      final perHour = result.putIfAbsent(day, () => <int, Map<String, Duration>>{});
      final perApp = perHour.putIfAbsent(
        row.hourIndex,
        () => <String, Duration>{},
      );
      perApp[row.appId] =
          (perApp[row.appId] ?? Duration.zero) +
          Duration(seconds: row.durationSeconds);
    }

    return result;
  }

  Future<void> deleteByAppId(String appId) {
    return (delete(
      dailyUsageEntries,
    )..where((tbl) => tbl.appId.equals(appId))).go();
  }

  Future<void> deleteByDateRange(DateTime start, DateTime end) {
    final startDay = _normalizeDay(start);
    final endDay = _normalizeDay(end);

    return (delete(
      dailyUsageEntries,
    )..where((tbl) => tbl.date.isBetweenValues(startDay, endDay))).go();
  }

  Future<void> clearAll() {
    return delete(dailyUsageEntries).go();
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'ringotrack');
}
