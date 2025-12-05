// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DailyUsageEntriesTable extends DailyUsageEntries
    with TableInfo<$DailyUsageEntriesTable, DailyUsageEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyUsageEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appIdMeta = const VerificationMeta('appId');
  @override
  late final GeneratedColumn<String> appId = GeneratedColumn<String>(
    'app_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [date, appId, durationSeconds];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_usage_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyUsageEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('app_id')) {
      context.handle(
        _appIdMeta,
        appId.isAcceptableOrUnknown(data['app_id']!, _appIdMeta),
      );
    } else if (isInserting) {
      context.missing(_appIdMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date, appId};
  @override
  DailyUsageEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyUsageEntry(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      appId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_id'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
    );
  }

  @override
  $DailyUsageEntriesTable createAlias(String alias) {
    return $DailyUsageEntriesTable(attachedDatabase, alias);
  }
}

class DailyUsageEntry extends DataClass implements Insertable<DailyUsageEntry> {
  /// 归一化到当天 00:00 的本地日期
  final DateTime date;

  /// AppId：Windows 下为 exe 名，macOS 下为 bundleId
  final String appId;

  /// 当天该 app 的总使用时长，单位：秒
  final int durationSeconds;
  const DailyUsageEntry({
    required this.date,
    required this.appId,
    required this.durationSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    map['app_id'] = Variable<String>(appId);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    return map;
  }

  DailyUsageEntriesCompanion toCompanion(bool nullToAbsent) {
    return DailyUsageEntriesCompanion(
      date: Value(date),
      appId: Value(appId),
      durationSeconds: Value(durationSeconds),
    );
  }

  factory DailyUsageEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyUsageEntry(
      date: serializer.fromJson<DateTime>(json['date']),
      appId: serializer.fromJson<String>(json['appId']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<DateTime>(date),
      'appId': serializer.toJson<String>(appId),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
    };
  }

  DailyUsageEntry copyWith({
    DateTime? date,
    String? appId,
    int? durationSeconds,
  }) => DailyUsageEntry(
    date: date ?? this.date,
    appId: appId ?? this.appId,
    durationSeconds: durationSeconds ?? this.durationSeconds,
  );
  DailyUsageEntry copyWithCompanion(DailyUsageEntriesCompanion data) {
    return DailyUsageEntry(
      date: data.date.present ? data.date.value : this.date,
      appId: data.appId.present ? data.appId.value : this.appId,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyUsageEntry(')
          ..write('date: $date, ')
          ..write('appId: $appId, ')
          ..write('durationSeconds: $durationSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, appId, durationSeconds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyUsageEntry &&
          other.date == this.date &&
          other.appId == this.appId &&
          other.durationSeconds == this.durationSeconds);
}

class DailyUsageEntriesCompanion extends UpdateCompanion<DailyUsageEntry> {
  final Value<DateTime> date;
  final Value<String> appId;
  final Value<int> durationSeconds;
  final Value<int> rowid;
  const DailyUsageEntriesCompanion({
    this.date = const Value.absent(),
    this.appId = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyUsageEntriesCompanion.insert({
    required DateTime date,
    required String appId,
    required int durationSeconds,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       appId = Value(appId),
       durationSeconds = Value(durationSeconds);
  static Insertable<DailyUsageEntry> custom({
    Expression<DateTime>? date,
    Expression<String>? appId,
    Expression<int>? durationSeconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (appId != null) 'app_id': appId,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyUsageEntriesCompanion copyWith({
    Value<DateTime>? date,
    Value<String>? appId,
    Value<int>? durationSeconds,
    Value<int>? rowid,
  }) {
    return DailyUsageEntriesCompanion(
      date: date ?? this.date,
      appId: appId ?? this.appId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (appId.present) {
      map['app_id'] = Variable<String>(appId.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyUsageEntriesCompanion(')
          ..write('date: $date, ')
          ..write('appId: $appId, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HourlyUsageEntriesTable extends HourlyUsageEntries
    with TableInfo<$HourlyUsageEntriesTable, HourlyUsageEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HourlyUsageEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hourIndexMeta = const VerificationMeta(
    'hourIndex',
  );
  @override
  late final GeneratedColumn<int> hourIndex = GeneratedColumn<int>(
    'hour_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appIdMeta = const VerificationMeta('appId');
  @override
  late final GeneratedColumn<String> appId = GeneratedColumn<String>(
    'app_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    hourIndex,
    appId,
    durationSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hourly_usage_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<HourlyUsageEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('hour_index')) {
      context.handle(
        _hourIndexMeta,
        hourIndex.isAcceptableOrUnknown(data['hour_index']!, _hourIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_hourIndexMeta);
    }
    if (data.containsKey('app_id')) {
      context.handle(
        _appIdMeta,
        appId.isAcceptableOrUnknown(data['app_id']!, _appIdMeta),
      );
    } else if (isInserting) {
      context.missing(_appIdMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date, hourIndex, appId};
  @override
  HourlyUsageEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HourlyUsageEntry(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      hourIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hour_index'],
      )!,
      appId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_id'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
    );
  }

  @override
  $HourlyUsageEntriesTable createAlias(String alias) {
    return $HourlyUsageEntriesTable(attachedDatabase, alias);
  }
}

class HourlyUsageEntry extends DataClass
    implements Insertable<HourlyUsageEntry> {
  /// 归一化到当天 00:00 的本地日期
  final DateTime date;

  /// 当天的第几个小时（0-23）
  final int hourIndex;

  /// AppId：Windows 下为 exe 名，macOS 下为 bundleId
  final String appId;

  /// 该小时内该 app 的总使用时长，单位：秒
  final int durationSeconds;
  const HourlyUsageEntry({
    required this.date,
    required this.hourIndex,
    required this.appId,
    required this.durationSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    map['hour_index'] = Variable<int>(hourIndex);
    map['app_id'] = Variable<String>(appId);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    return map;
  }

  HourlyUsageEntriesCompanion toCompanion(bool nullToAbsent) {
    return HourlyUsageEntriesCompanion(
      date: Value(date),
      hourIndex: Value(hourIndex),
      appId: Value(appId),
      durationSeconds: Value(durationSeconds),
    );
  }

  factory HourlyUsageEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HourlyUsageEntry(
      date: serializer.fromJson<DateTime>(json['date']),
      hourIndex: serializer.fromJson<int>(json['hourIndex']),
      appId: serializer.fromJson<String>(json['appId']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<DateTime>(date),
      'hourIndex': serializer.toJson<int>(hourIndex),
      'appId': serializer.toJson<String>(appId),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
    };
  }

  HourlyUsageEntry copyWith({
    DateTime? date,
    int? hourIndex,
    String? appId,
    int? durationSeconds,
  }) => HourlyUsageEntry(
    date: date ?? this.date,
    hourIndex: hourIndex ?? this.hourIndex,
    appId: appId ?? this.appId,
    durationSeconds: durationSeconds ?? this.durationSeconds,
  );
  HourlyUsageEntry copyWithCompanion(HourlyUsageEntriesCompanion data) {
    return HourlyUsageEntry(
      date: data.date.present ? data.date.value : this.date,
      hourIndex: data.hourIndex.present ? data.hourIndex.value : this.hourIndex,
      appId: data.appId.present ? data.appId.value : this.appId,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HourlyUsageEntry(')
          ..write('date: $date, ')
          ..write('hourIndex: $hourIndex, ')
          ..write('appId: $appId, ')
          ..write('durationSeconds: $durationSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, hourIndex, appId, durationSeconds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HourlyUsageEntry &&
          other.date == this.date &&
          other.hourIndex == this.hourIndex &&
          other.appId == this.appId &&
          other.durationSeconds == this.durationSeconds);
}

class HourlyUsageEntriesCompanion extends UpdateCompanion<HourlyUsageEntry> {
  final Value<DateTime> date;
  final Value<int> hourIndex;
  final Value<String> appId;
  final Value<int> durationSeconds;
  final Value<int> rowid;
  const HourlyUsageEntriesCompanion({
    this.date = const Value.absent(),
    this.hourIndex = const Value.absent(),
    this.appId = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HourlyUsageEntriesCompanion.insert({
    required DateTime date,
    required int hourIndex,
    required String appId,
    required int durationSeconds,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       hourIndex = Value(hourIndex),
       appId = Value(appId),
       durationSeconds = Value(durationSeconds);
  static Insertable<HourlyUsageEntry> custom({
    Expression<DateTime>? date,
    Expression<int>? hourIndex,
    Expression<String>? appId,
    Expression<int>? durationSeconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (hourIndex != null) 'hour_index': hourIndex,
      if (appId != null) 'app_id': appId,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HourlyUsageEntriesCompanion copyWith({
    Value<DateTime>? date,
    Value<int>? hourIndex,
    Value<String>? appId,
    Value<int>? durationSeconds,
    Value<int>? rowid,
  }) {
    return HourlyUsageEntriesCompanion(
      date: date ?? this.date,
      hourIndex: hourIndex ?? this.hourIndex,
      appId: appId ?? this.appId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (hourIndex.present) {
      map['hour_index'] = Variable<int>(hourIndex.value);
    }
    if (appId.present) {
      map['app_id'] = Variable<String>(appId.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HourlyUsageEntriesCompanion(')
          ..write('date: $date, ')
          ..write('hourIndex: $hourIndex, ')
          ..write('appId: $appId, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DailyUsageEntriesTable dailyUsageEntries =
      $DailyUsageEntriesTable(this);
  late final $HourlyUsageEntriesTable hourlyUsageEntries =
      $HourlyUsageEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dailyUsageEntries,
    hourlyUsageEntries,
  ];
}

typedef $$DailyUsageEntriesTableCreateCompanionBuilder =
    DailyUsageEntriesCompanion Function({
      required DateTime date,
      required String appId,
      required int durationSeconds,
      Value<int> rowid,
    });
typedef $$DailyUsageEntriesTableUpdateCompanionBuilder =
    DailyUsageEntriesCompanion Function({
      Value<DateTime> date,
      Value<String> appId,
      Value<int> durationSeconds,
      Value<int> rowid,
    });

class $$DailyUsageEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DailyUsageEntriesTable> {
  $$DailyUsageEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appId => $composableBuilder(
    column: $table.appId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyUsageEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyUsageEntriesTable> {
  $$DailyUsageEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appId => $composableBuilder(
    column: $table.appId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyUsageEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyUsageEntriesTable> {
  $$DailyUsageEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get appId =>
      $composableBuilder(column: $table.appId, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );
}

class $$DailyUsageEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyUsageEntriesTable,
          DailyUsageEntry,
          $$DailyUsageEntriesTableFilterComposer,
          $$DailyUsageEntriesTableOrderingComposer,
          $$DailyUsageEntriesTableAnnotationComposer,
          $$DailyUsageEntriesTableCreateCompanionBuilder,
          $$DailyUsageEntriesTableUpdateCompanionBuilder,
          (
            DailyUsageEntry,
            BaseReferences<
              _$AppDatabase,
              $DailyUsageEntriesTable,
              DailyUsageEntry
            >,
          ),
          DailyUsageEntry,
          PrefetchHooks Function()
        > {
  $$DailyUsageEntriesTableTableManager(
    _$AppDatabase db,
    $DailyUsageEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyUsageEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyUsageEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyUsageEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<String> appId = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyUsageEntriesCompanion(
                date: date,
                appId: appId,
                durationSeconds: durationSeconds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required String appId,
                required int durationSeconds,
                Value<int> rowid = const Value.absent(),
              }) => DailyUsageEntriesCompanion.insert(
                date: date,
                appId: appId,
                durationSeconds: durationSeconds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyUsageEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyUsageEntriesTable,
      DailyUsageEntry,
      $$DailyUsageEntriesTableFilterComposer,
      $$DailyUsageEntriesTableOrderingComposer,
      $$DailyUsageEntriesTableAnnotationComposer,
      $$DailyUsageEntriesTableCreateCompanionBuilder,
      $$DailyUsageEntriesTableUpdateCompanionBuilder,
      (
        DailyUsageEntry,
        BaseReferences<_$AppDatabase, $DailyUsageEntriesTable, DailyUsageEntry>,
      ),
      DailyUsageEntry,
      PrefetchHooks Function()
    >;
typedef $$HourlyUsageEntriesTableCreateCompanionBuilder =
    HourlyUsageEntriesCompanion Function({
      required DateTime date,
      required int hourIndex,
      required String appId,
      required int durationSeconds,
      Value<int> rowid,
    });
typedef $$HourlyUsageEntriesTableUpdateCompanionBuilder =
    HourlyUsageEntriesCompanion Function({
      Value<DateTime> date,
      Value<int> hourIndex,
      Value<String> appId,
      Value<int> durationSeconds,
      Value<int> rowid,
    });

class $$HourlyUsageEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $HourlyUsageEntriesTable> {
  $$HourlyUsageEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hourIndex => $composableBuilder(
    column: $table.hourIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appId => $composableBuilder(
    column: $table.appId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HourlyUsageEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $HourlyUsageEntriesTable> {
  $$HourlyUsageEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hourIndex => $composableBuilder(
    column: $table.hourIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appId => $composableBuilder(
    column: $table.appId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HourlyUsageEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HourlyUsageEntriesTable> {
  $$HourlyUsageEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get hourIndex =>
      $composableBuilder(column: $table.hourIndex, builder: (column) => column);

  GeneratedColumn<String> get appId =>
      $composableBuilder(column: $table.appId, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );
}

class $$HourlyUsageEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HourlyUsageEntriesTable,
          HourlyUsageEntry,
          $$HourlyUsageEntriesTableFilterComposer,
          $$HourlyUsageEntriesTableOrderingComposer,
          $$HourlyUsageEntriesTableAnnotationComposer,
          $$HourlyUsageEntriesTableCreateCompanionBuilder,
          $$HourlyUsageEntriesTableUpdateCompanionBuilder,
          (
            HourlyUsageEntry,
            BaseReferences<
              _$AppDatabase,
              $HourlyUsageEntriesTable,
              HourlyUsageEntry
            >,
          ),
          HourlyUsageEntry,
          PrefetchHooks Function()
        > {
  $$HourlyUsageEntriesTableTableManager(
    _$AppDatabase db,
    $HourlyUsageEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HourlyUsageEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HourlyUsageEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HourlyUsageEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<int> hourIndex = const Value.absent(),
                Value<String> appId = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HourlyUsageEntriesCompanion(
                date: date,
                hourIndex: hourIndex,
                appId: appId,
                durationSeconds: durationSeconds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required int hourIndex,
                required String appId,
                required int durationSeconds,
                Value<int> rowid = const Value.absent(),
              }) => HourlyUsageEntriesCompanion.insert(
                date: date,
                hourIndex: hourIndex,
                appId: appId,
                durationSeconds: durationSeconds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HourlyUsageEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HourlyUsageEntriesTable,
      HourlyUsageEntry,
      $$HourlyUsageEntriesTableFilterComposer,
      $$HourlyUsageEntriesTableOrderingComposer,
      $$HourlyUsageEntriesTableAnnotationComposer,
      $$HourlyUsageEntriesTableCreateCompanionBuilder,
      $$HourlyUsageEntriesTableUpdateCompanionBuilder,
      (
        HourlyUsageEntry,
        BaseReferences<
          _$AppDatabase,
          $HourlyUsageEntriesTable,
          HourlyUsageEntry
        >,
      ),
      HourlyUsageEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DailyUsageEntriesTableTableManager get dailyUsageEntries =>
      $$DailyUsageEntriesTableTableManager(_db, _db.dailyUsageEntries);
  $$HourlyUsageEntriesTableTableManager get hourlyUsageEntries =>
      $$HourlyUsageEntriesTableTableManager(_db, _db.hourlyUsageEntries);
}
