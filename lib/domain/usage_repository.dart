import 'package:ringotrack/domain/app_database.dart';

/// UsageRepository 抽象，后续如果需要可以有内存版 / SQLite 版等多种实现。
abstract class UsageRepository {
  Future<Map<DateTime, Map<String, Duration>>> loadRange(
    DateTime start,
    DateTime end,
  );

  Future<void> mergeUsage(Map<DateTime, Map<String, Duration>> delta);
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
}

