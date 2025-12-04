import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:ringotrack/domain/usage_models.dart';

/// 统一的前台应用切换事件跟踪接口
abstract class ForegroundAppTracker {
  Stream<ForegroundAppEvent> get events;
}

class _MacOsForegroundAppTracker implements ForegroundAppTracker {
  _MacOsForegroundAppTracker() {
    _subscription = _eventChannel
        .receiveBroadcastStream()
        .listen(_handleEvent, onError: _handleError);
  }

  static const _eventChannel =
      EventChannel('ringotrack/foreground_app_events');

  final _controller = StreamController<ForegroundAppEvent>.broadcast();
  late final StreamSubscription<dynamic> _subscription;

  @override
  Stream<ForegroundAppEvent> get events => _controller.stream;

  void _handleEvent(dynamic event) {
    if (event is Map) {
      final appId = event['appId'] as String?;
      final tsMillis = event['timestamp'] as num?;
      if (appId == null || tsMillis == null) return;

      final timestamp =
          DateTime.fromMillisecondsSinceEpoch(tsMillis.toInt(), isUtc: false);
      _controller.add(
        ForegroundAppEvent(appId: appId, timestamp: timestamp),
      );
    }
  }

  void _handleError(Object error) {
    // 暂时忽略错误，后续可以接入日志系统
  }
}

class _NoopForegroundAppTracker implements ForegroundAppTracker {
  @override
  Stream<ForegroundAppEvent> get events => const Stream.empty();
}

ForegroundAppTracker createForegroundAppTracker() {
  if (Platform.isMacOS) {
    return _MacOsForegroundAppTracker();
  }

  // TODO: Windows 平台后续接 win32 FFI 实现
  return _NoopForegroundAppTracker();
}

