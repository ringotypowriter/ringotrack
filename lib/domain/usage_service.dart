import 'dart:async';

import 'package:ringotrack/domain/usage_models.dart';
import 'package:ringotrack/domain/usage_repository.dart';
import 'package:ringotrack/platform/foreground_app_tracker.dart';

/// 负责把「前台 App 事件」转换成「按日统计 + 持久化」的应用服务
class UsageService {
  UsageService({
    required this.isDrawingApp,
    required this.repository,
    required this.tracker,
  }) {
    _aggregator = UsageAggregator(isDrawingApp: isDrawingApp);
    _subscription = tracker.events.listen(_onEvent);
  }

  final bool Function(String appId) isDrawingApp;
  final UsageRepository repository;
  final ForegroundAppTracker tracker;

  late final UsageAggregator _aggregator;
  late final StreamSubscription<ForegroundAppEvent> _subscription;

  Future<void> _onEvent(ForegroundAppEvent event) async {
    _aggregator.onForegroundAppChanged(event);
    final delta = _aggregator.drainUsage();
    if (delta.isNotEmpty) {
      await repository.mergeUsage(delta);
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
    _aggregator.closeAt(DateTime.now());
    final delta = _aggregator.drainUsage();
    if (delta.isNotEmpty) {
      await repository.mergeUsage(delta);
    }
  }
}

