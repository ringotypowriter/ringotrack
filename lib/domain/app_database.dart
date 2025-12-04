import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

@DriftDatabase(tables: [DailyUsageEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 提供给单元测试等场景自定义连接（例如内存数据库）
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  DateTime _normalizeDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 将增量 usage 合并到数据库里（按天 + appId 叠加时长）
  Future<void> mergeUsage(
    Map<DateTime, Map<String, Duration>> delta,
  ) async {
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

    final rows = await (select(dailyUsageEntries)
          ..where(
            (tbl) => tbl.date.isBetweenValues(startDay, endDay),
          ))
        .get();

    final result = <DateTime, Map<String, Duration>>{};
    for (final row in rows) {
      final day = _normalizeDay(row.date);
      final perApp = result.putIfAbsent(day, () => {});
      perApp[row.appId] =
          (perApp[row.appId] ?? Duration.zero) + Duration(seconds: row.durationSeconds);
    }
    return result;
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'ringotrack.sqlite',
  );
}
