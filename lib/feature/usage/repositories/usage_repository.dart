import 'package:ringotrack/feature/database/services/app_database.dart';

/// UsageRepository 抽象，后续如果需要可以有内存版 / SQLite 版等多种实现。
abstract class UsageRepository {
  Future<Map<DateTime, Map<String, Duration>>> loadRange(
    DateTime start,
    DateTime end,
  );

  Future<void> mergeUsage(Map<DateTime, Map<String, Duration>> delta);

  /// 按「日 + 小时 + App」返回使用时长。
  ///
  /// - 外层 key：归一化到当天 00:00 的本地日期；
  /// - 第二层 key：hourIndex（0-23）；
  /// - 最内层 key：appId。
  Future<Map<DateTime, Map<int, Map<String, Duration>>>> loadHourlyRange(
    DateTime start,
    DateTime end,
  );

  /// 合并小时级增量，按「日 + 小时 + appId」叠加时长。
  Future<void> mergeHourlyUsage(
    Map<DateTime, Map<int, Map<String, Duration>>> delta,
  );

  Future<void> deleteByAppId(String appId);

  Future<void> deleteByDateRange(DateTime start, DateTime end);

  Future<void> clearAll();
}

class SqliteUsageRepository implements UsageRepository {
  SqliteUsageRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Map<DateTime, Map<String, Duration>>> loadRange(
    DateTime start,
    DateTime end,
  ) {
    return _db.loadRange(start, end);
  }

  @override
  Future<void> mergeUsage(Map<DateTime, Map<String, Duration>> delta) {
    return _db.mergeUsage(delta);
  }

  @override
  Future<Map<DateTime, Map<int, Map<String, Duration>>>> loadHourlyRange(
    DateTime start,
    DateTime end,
  ) {
    return _db.loadHourlyRange(start, end);
  }

  @override
  Future<void> mergeHourlyUsage(
    Map<DateTime, Map<int, Map<String, Duration>>> delta,
  ) {
    return _db.mergeHourlyUsage(delta);
  }

  @override
  Future<void> deleteByAppId(String appId) {
    return _db.deleteByAppId(appId);
  }

  @override
  Future<void> deleteByDateRange(DateTime start, DateTime end) {
    return _db.deleteByDateRange(start, end);
  }

  @override
  Future<void> clearAll() {
    return _db.clearAll();
  }
}
