import 'package:ringotrack/domain/app_database.dart';

/// UsageRepository 抽象，后续如果需要可以有内存版 / SQLite 版等多种实现。
abstract class UsageRepository {
  Future<Map<DateTime, Map<String, Duration>>> loadRange(
    DateTime start,
    DateTime end,
  );

  Future<void> mergeUsage(Map<DateTime, Map<String, Duration>> delta);

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
