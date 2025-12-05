import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ringotrack/domain/usage_models.dart';
import 'package:ringotrack/domain/usage_repository.dart';
import 'package:ringotrack/platform/foreground_app_tracker.dart';
import 'package:ringotrack/platform/stroke_activity_tracker.dart';
import 'package:ringotrack/domain/app_log_service.dart';

/// 负责把「前台 App 事件」转换成「按日统计 + 持久化」的应用服务
class UsageService {
  UsageService({
    required this.isDrawingApp,
    required this.repository,
    required this.tracker,
    required this.strokeTracker,
    this.idleThreshold = const Duration(minutes: 1),
    this.dbFlushInterval = const Duration(seconds: 5),
  }) {
    if (kDebugMode) {
      debugPrint('[UsageService] created and subscribing to tracker events');
    }

    _hourlyAggregator = HourlyUsageAggregator(isDrawingApp: isDrawingApp);
    _foregroundSubscription = tracker.events.listen(_onForegroundEvent);
    _strokeSubscription = strokeTracker.strokes.listen(_onStrokeEvent);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  final bool Function(String appId) isDrawingApp;
  final UsageRepository repository;
  final ForegroundAppTracker tracker;
  final StrokeActivityTracker strokeTracker;
  final Duration idleThreshold;
  final Duration dbFlushInterval;

  late final HourlyUsageAggregator _hourlyAggregator;
  late final StreamSubscription<ForegroundAppEvent> _foregroundSubscription;
  StreamSubscription<StrokeEvent>? _strokeSubscription;
  Timer? _tickTimer;

  final _deltaController =
      StreamController<Map<DateTime, Map<String, Duration>>>.broadcast();

  static const _idleAppId = '__ringotrack_idle__';

  String? _currentForegroundAppId;
  DateTime _lastStrokeTime = DateTime.now();
  bool _isIdle = false;
  bool _pointerDown = false;

  final Map<DateTime, Map<String, Duration>> _pendingDbDelta = {};
  final Map<DateTime, Map<int, Map<String, Duration>>> _pendingHourlyDbDelta =
      {};
  final Map<DateTime, Map<int, Map<String, Duration>>>
      _fractionalHourlyRemainder = {};
  DateTime _lastDbFlushAt = DateTime.now();
  bool _isFlushingDb = false;

  /// 每次有非空增量写入时，都会向外广播一份 delta，
  /// 方便 UI 侧增量刷新统计数据。
  Stream<Map<DateTime, Map<String, Duration>>> get deltaStream =>
      _deltaController.stream;

  Future<void> _onForegroundEvent(ForegroundAppEvent event) async {
    if (kDebugMode) {
      debugPrint(
        '[UsageService] onForegroundAppChanged: appId=${event.appId} '
        'timestamp=${event.timestamp.toIso8601String()}',
      );
    }

    // 统一日志：无论 macOS 还是 Windows，都记录一条前台事件日志
    AppLogService.instance.logDebug(
      'usage_service',
      'onForegroundAppChanged appId=${event.appId} '
          'timestamp=${event.timestamp.toIso8601String()}',
    );

    _currentForegroundAppId = event.appId;

    if (_isIdle) {
      // Idle 状态下不计时，只更新当前前台 appId 以便恢复后继续。
      return;
    }

    _hourlyAggregator.onForegroundAppChanged(event);
    await _flushAggregatorDelta();
  }

  void _onStrokeEvent(StrokeEvent event) {
    _lastStrokeTime = event.timestamp;
    _pointerDown = event.isDown;
    if (_isIdle && !_pointerDown) {
      // still idle until pointer really active again
      return;
    }
    if (_isIdle && _pointerDown) {
      _leaveIdle(event.timestamp);
    }
  }

  Future<void> _onTick(Timer timer) async {
    final now = DateTime.now();
    if (_pointerDown) {
      _lastStrokeTime = now;
    }

    final idleDuration = now.difference(_lastStrokeTime);
    final nowIdle = idleDuration >= idleThreshold;

    if (!_isIdle && nowIdle) {
      // 进入 Idle：记录详细日志，方便在 Windows/macOS 下核对阈值是否为 60s。
      if (kDebugMode) {
        debugPrint(
          '[UsageService][AFK] enter idle '
          'platform=${Platform.operatingSystem} '
          'idleDurationMs=${idleDuration.inMilliseconds} '
          'lastStroke=$_lastStrokeTime now=$now '
          'pointerDown=$_pointerDown',
        );
      }
      AppLogService.instance.logInfo(
        'usage_afk',
        'enter_idle platform=${Platform.operatingSystem} '
            'idleDurationMs=${idleDuration.inMilliseconds} '
            'lastStroke=$_lastStrokeTime now=$now '
            'pointerDown=$_pointerDown',
      );

      _enterIdle(now);
      await _flushAggregatorDelta();
      return;
    }

    if (_isIdle && !nowIdle) {
      if (kDebugMode) {
        debugPrint(
          '[UsageService][AFK] leave idle '
          'platform=${Platform.operatingSystem} '
          'idleDurationMs=${idleDuration.inMilliseconds} '
          'lastStroke=$_lastStrokeTime now=$now '
          'pointerDown=$_pointerDown',
        );
      }
      AppLogService.instance.logInfo(
        'usage_afk',
        'leave_idle platform=${Platform.operatingSystem} '
            'idleDurationMs=${idleDuration.inMilliseconds} '
            'lastStroke=$_lastStrokeTime now=$now '
            'pointerDown=$_pointerDown',
      );

      _leaveIdle(now);
      await _flushAggregatorDelta();
      return;
    }

    if (_isIdle) {
      return;
    }

    if (_currentForegroundAppId != null) {
      _hourlyAggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: _currentForegroundAppId!, timestamp: now),
      );
      await _flushAggregatorDelta();
    }
  }

  void _enterIdle(DateTime now) {
    if (_isIdle) return;
    _isIdle = true;
    if (_currentForegroundAppId != null) {
      _hourlyAggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: _idleAppId, timestamp: now),
      );
    }
  }

  void _leaveIdle(DateTime now) {
    if (!_isIdle) return;
    _isIdle = false;
    if (_currentForegroundAppId != null) {
      _hourlyAggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: _currentForegroundAppId!, timestamp: now),
      );
    }
  }

  Future<void> _flushAggregatorDelta() async {
    final rawHourlyDelta = _hourlyAggregator.drainUsage();

    if (rawHourlyDelta.isEmpty) {
      return;
    }

    final hourlyDelta = quantizeHourlyUsageWithRemainder(
      rawHourlyDelta,
      _fractionalHourlyRemainder,
    );

    if (hourlyDelta.isEmpty) {
      return;
    }

    if (kDebugMode) {
      final bufferHourly = StringBuffer('[UsageService] hourly delta:');
      hourlyDelta.forEach((day, perHour) {
        perHour.forEach((hour, perApp) {
          perApp.forEach((appId, duration) {
            bufferHourly.write(
              '\n  $day H$hour $appId -> ${duration.inSeconds}s',
            );
          });
        });
      });
      debugPrint(bufferHourly.toString());
    }

    final dailyDelta = <DateTime, Map<String, Duration>>{};
    hourlyDelta.forEach((day, perHour) {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      final perAppDaily = dailyDelta.putIfAbsent(
        normalizedDay,
        () => <String, Duration>{},
      );
      perHour.forEach((_, perApp) {
        perApp.forEach((appId, duration) {
          perAppDaily[appId] =
              (perAppDaily[appId] ?? Duration.zero) + duration;
        });
      });
    });

    if (dailyDelta.isNotEmpty) {
      _deltaController.add(dailyDelta);
      _mergePendingDbDelta(dailyDelta);
    }

    _mergePendingHourlyDbDelta(hourlyDelta);

    await _flushDbDeltaIfNeeded();
  }

  Future<void> close() async {
    await _foregroundSubscription.cancel();
    await _strokeSubscription?.cancel();
    _tickTimer?.cancel();
    _hourlyAggregator.closeAt(DateTime.now());
    await _flushAggregatorDelta();
    await _flushDbDelta(force: true);
    await _deltaController.close();
  }

  void _mergePendingDbDelta(Map<DateTime, Map<String, Duration>> delta) {
    delta.forEach((day, perApp) {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      final existingPerApp = _pendingDbDelta.putIfAbsent(
        normalizedDay,
        () => <String, Duration>{},
      );

      perApp.forEach((appId, duration) {
        existingPerApp[appId] =
            (existingPerApp[appId] ?? Duration.zero) + duration;
      });
    });
  }

  void _mergePendingHourlyDbDelta(
    Map<DateTime, Map<int, Map<String, Duration>>> delta,
  ) {
    delta.forEach((day, perHour) {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      final existingPerHour = _pendingHourlyDbDelta.putIfAbsent(
        normalizedDay,
        () => <int, Map<String, Duration>>{},
      );

      perHour.forEach((hourIndex, perApp) {
        final existingPerApp = existingPerHour.putIfAbsent(
          hourIndex,
          () => <String, Duration>{},
        );
        perApp.forEach((appId, duration) {
          existingPerApp[appId] =
              (existingPerApp[appId] ?? Duration.zero) + duration;
        });
      });
    });
  }

  Future<void> _flushDbDeltaIfNeeded() async {
    final now = DateTime.now();
    if (now.difference(_lastDbFlushAt) < dbFlushInterval) {
      return;
    }
    await _flushDbDelta();
  }

  Future<void> _flushDbDelta({bool force = false}) async {
    if (_isFlushingDb) {
      return;
    }
    if (!force &&
        _pendingDbDelta.isEmpty &&
        _pendingHourlyDbDelta.isEmpty) {
      return;
    }

    _isFlushingDb = true;
    final toPersistDaily = Map<DateTime, Map<String, Duration>>.from(
      _pendingDbDelta,
    );
    final toPersistHourly =
        Map<DateTime, Map<int, Map<String, Duration>>>.from(
          _pendingHourlyDbDelta,
        );
    _pendingDbDelta.clear();
    _pendingHourlyDbDelta.clear();
    _lastDbFlushAt = DateTime.now();
    try {
      if (toPersistDaily.isNotEmpty) {
        // 记录日志方便排查
        toPersistDaily.forEach((day, perApp) {
          perApp.forEach((appId, duration) {
            AppLogService.instance.logInfo(
              'usage_service',
              'persist delta day=$day appId=$appId '
                  'duration=${duration.inSeconds}s',
            );
          });
        });
        await repository.mergeUsage(toPersistDaily);
      }

      if (toPersistHourly.isNotEmpty) {
        toPersistHourly.forEach((day, perHour) {
          perHour.forEach((hour, perApp) {
            perApp.forEach((appId, duration) {
              AppLogService.instance.logInfo(
                'usage_service',
                'persist hourly delta day=$day hour=$hour appId=$appId '
                    'duration=${duration.inSeconds}s',
              );
            });
          });
        });
        await repository.mergeHourlyUsage(toPersistHourly);
      }
    } finally {
      _isFlushingDb = false;
    }
  }
}

/// 将 UsageAggregator 的毫秒级增量与现有的「余数」一起量化为整秒输出。
///
/// - [rawDelta]: 本次聚合产生的增量（毫秒级）。
/// - [fractionalRemainder]: 按 (day, appId) 存储的「未满 1 秒」余数，会被就地更新。
///
/// 返回值是本次应向 UI / DB 输出的「整秒」增量；所有不足 1 秒的部分会继续累积在
/// [fractionalRemainder] 中，以避免高频 flush 时被丢弃。
Map<DateTime, Map<String, Duration>> quantizeUsageWithRemainder(
  Map<DateTime, Map<String, Duration>> rawDelta,
  Map<DateTime, Map<String, Duration>> fractionalRemainder,
) {
  final result = <DateTime, Map<String, Duration>>{};

  rawDelta.forEach((day, perApp) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final perAppSeconds = <String, Duration>{};

    perApp.forEach((appId, duration) {
      final dayRemainder = fractionalRemainder.putIfAbsent(
        normalizedDay,
        () => <String, Duration>{},
      );
      final previousRemainder = dayRemainder[appId] ?? Duration.zero;

      final total = previousRemainder + duration;
      final wholeSeconds = total.inSeconds;
      final remainder = total - Duration(seconds: wholeSeconds);

      if (wholeSeconds > 0) {
        perAppSeconds[appId] = Duration(seconds: wholeSeconds);
      }

      if (remainder == Duration.zero) {
        dayRemainder.remove(appId);
        if (dayRemainder.isEmpty) {
          fractionalRemainder.remove(normalizedDay);
        }
      } else {
        dayRemainder[appId] = remainder;
      }
    });

    if (perAppSeconds.isNotEmpty) {
      result[normalizedDay] = perAppSeconds;
    }
  });

  return result;
}

/// 将小时级增量 usage 与现有的「余数」一起量化为整秒输出。
///
/// 结构与 [quantizeUsageWithRemainder] 类似，但多了一层 hourIndex 维度。
Map<DateTime, Map<int, Map<String, Duration>>> quantizeHourlyUsageWithRemainder(
  Map<DateTime, Map<int, Map<String, Duration>>> rawDelta,
  Map<DateTime, Map<int, Map<String, Duration>>> fractionalRemainder,
) {
  final result = <DateTime, Map<int, Map<String, Duration>>>{};

  rawDelta.forEach((day, perHour) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final perHourSeconds = <int, Map<String, Duration>>{};

    perHour.forEach((hourIndex, perApp) {
      final dayRemainder = fractionalRemainder.putIfAbsent(
        normalizedDay,
        () => <int, Map<String, Duration>>{},
      );
      final hourRemainder = dayRemainder.putIfAbsent(
        hourIndex,
        () => <String, Duration>{},
      );

      final perAppSeconds = <String, Duration>{};

      perApp.forEach((appId, duration) {
        final previousRemainder = hourRemainder[appId] ?? Duration.zero;

        final total = previousRemainder + duration;
        final wholeSeconds = total.inSeconds;
        final remainder = total - Duration(seconds: wholeSeconds);

        if (wholeSeconds > 0) {
          perAppSeconds[appId] = Duration(seconds: wholeSeconds);
        }

        if (remainder == Duration.zero) {
          hourRemainder.remove(appId);
        } else {
          hourRemainder[appId] = remainder;
        }
      });

      if (hourRemainder.isEmpty) {
        dayRemainder.remove(hourIndex);
        if (dayRemainder.isEmpty) {
          fractionalRemainder.remove(normalizedDay);
        }
      }

      if (perAppSeconds.isNotEmpty) {
        perHourSeconds[hourIndex] = perAppSeconds;
      }
    });

    if (perHourSeconds.isNotEmpty) {
      result[normalizedDay] = perHourSeconds;
    }
  });

  return result;
}
