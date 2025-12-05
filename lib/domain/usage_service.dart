import 'dart:async';

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

    _aggregator = UsageAggregator(isDrawingApp: isDrawingApp);
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

  late final UsageAggregator _aggregator;
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

    _aggregator.onForegroundAppChanged(event);
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
      // 长按/落笔持续视为活跃，避免超过阈值被误判 idle。
      _lastStrokeTime = now;
      if (_isIdle) {
        _leaveIdle(now);
      }
    }

    final idleDuration = now.difference(_lastStrokeTime);
    final nowIdle = idleDuration >= idleThreshold;

    if (!_isIdle && nowIdle) {
      _enterIdle(now);
      await _flushAggregatorDelta();
      return;
    }

    if (_isIdle && !nowIdle) {
      _leaveIdle(now);
      await _flushAggregatorDelta();
      return;
    }

    if (_isIdle) {
      return;
    }

    if (_currentForegroundAppId != null) {
      _aggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: _currentForegroundAppId!, timestamp: now),
      );
      await _flushAggregatorDelta();
    }
  }

  void _enterIdle(DateTime now) {
    if (_isIdle) return;
    _isIdle = true;
    if (_currentForegroundAppId != null) {
      _aggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: _idleAppId, timestamp: now),
      );
    }
  }

  void _leaveIdle(DateTime now) {
    if (!_isIdle) return;
    _isIdle = false;
    if (_currentForegroundAppId != null) {
      _aggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: _currentForegroundAppId!, timestamp: now),
      );
    }
  }

  Future<void> _flushAggregatorDelta() async {
    final rawDelta = _aggregator.drainUsage();
    if (rawDelta.isEmpty) {
      return;
    }

    // 为了让实时 UI 与持久化后的结果严格按「整秒」对齐，这里将聚合结果
    // 统一量化到整数秒：对每个 (day, appId) 只保留 duration.inSeconds。
    final delta = <DateTime, Map<String, Duration>>{};
    rawDelta.forEach((day, perApp) {
      final perAppSeconds = <String, Duration>{};
      perApp.forEach((appId, duration) {
        final seconds = duration.inSeconds;
        if (seconds <= 0) return;
        perAppSeconds[appId] = Duration(seconds: seconds);
      });
      if (perAppSeconds.isNotEmpty) {
        delta[day] = perAppSeconds;
      }
    });

    if (delta.isEmpty) {
      return;
    }

    if (kDebugMode) {
      final buffer = StringBuffer('[UsageService] delta:');
      delta.forEach((day, perApp) {
        perApp.forEach((appId, duration) {
          buffer.write('\n  $day $appId -> ${duration.inSeconds}s');
        });
      });
      debugPrint(buffer.toString());
    }

    _deltaController.add(delta);
    _mergePendingDbDelta(delta);
    await _flushDbDeltaIfNeeded();
  }

  Future<void> close() async {
    await _foregroundSubscription.cancel();
    await _strokeSubscription?.cancel();
    _tickTimer?.cancel();
    _aggregator.closeAt(DateTime.now());
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
    if (!force && _pendingDbDelta.isEmpty) {
      return;
    }

    _isFlushingDb = true;
    final toPersist =
        Map<DateTime, Map<String, Duration>>.from(_pendingDbDelta);
    _pendingDbDelta.clear();
    _lastDbFlushAt = DateTime.now();
    try {
      if (toPersist.isNotEmpty) {
        // 记录日志方便排查
        toPersist.forEach((day, perApp) {
          perApp.forEach((appId, duration) {
            AppLogService.instance.logInfo(
              'usage_service',
              'persist delta day=$day appId=$appId '
                  'duration=${duration.inSeconds}s',
            );
          });
        });
        await repository.mergeUsage(toPersist);
      }
    } finally {
      _isFlushingDb = false;
    }
  }
}
