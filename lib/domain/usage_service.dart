import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ringotrack/domain/usage_models.dart';
import 'package:ringotrack/domain/usage_repository.dart';
import 'package:ringotrack/platform/foreground_app_tracker.dart';
import 'package:ringotrack/domain/app_log_service.dart';

/// 负责把「前台 App 事件」转换成「按日统计 + 持久化」的应用服务
class UsageService {
  UsageService({
    required this.isDrawingApp,
    required this.repository,
    required this.tracker,
  }) {
    if (kDebugMode) {
      debugPrint('[UsageService] created and subscribing to tracker events');
    }

    _aggregator = UsageAggregator(isDrawingApp: isDrawingApp);
    _subscription = tracker.events.listen(_onEvent);
  }

  final bool Function(String appId) isDrawingApp;
  final UsageRepository repository;
  final ForegroundAppTracker tracker;

  late final UsageAggregator _aggregator;
  late final StreamSubscription<ForegroundAppEvent> _subscription;

  final _deltaController =
      StreamController<Map<DateTime, Map<String, Duration>>>.broadcast();

  /// 每次有非空增量写入时，都会向外广播一份 delta，
  /// 方便 UI 侧增量刷新统计数据。
  Stream<Map<DateTime, Map<String, Duration>>> get deltaStream =>
      _deltaController.stream;

  Future<void> _onEvent(ForegroundAppEvent event) async {
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

    _aggregator.onForegroundAppChanged(event);
    final delta = _aggregator.drainUsage();
    if (delta.isNotEmpty) {
      if (kDebugMode) {
        final buffer = StringBuffer('[UsageService] persist delta:');
        delta.forEach((day, perApp) {
          perApp.forEach((appId, duration) {
            buffer.write(
              '\n  $day $appId -> ${duration.inSeconds}s',
            );
          });
        });
        debugPrint(buffer.toString());
      }

      // 把聚合写库的增量也打到统一日志，方便跨平台排查
      delta.forEach((day, perApp) {
        perApp.forEach((appId, duration) {
          AppLogService.instance.logInfo(
            'usage_service',
            'persist delta day=$day appId=$appId '
            'duration=${duration.inSeconds}s',
          );
        });
      });

      _deltaController.add(delta);
      await repository.mergeUsage(delta);
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
    _aggregator.closeAt(DateTime.now());
    final delta = _aggregator.drainUsage();
    if (delta.isNotEmpty) {
      _deltaController.add(delta);
      await repository.mergeUsage(delta);
    }
    await _deltaController.close();
  }
}
