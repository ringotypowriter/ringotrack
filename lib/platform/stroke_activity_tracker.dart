import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ringotrack/domain/app_log_service.dart';

typedef RtInitStrokeHookNative = ffi.Void Function();
typedef RtInitStrokeHookDart = void Function();
typedef RtGetLastStrokeMillisNative = ffi.Uint64 Function();
typedef RtGetLastStrokeMillisDart = int Function();
typedef RtIsLeftButtonDownNative = ffi.Uint32 Function();
typedef RtIsLeftButtonDownDart = int Function();

class StrokeEvent {
  StrokeEvent({required this.timestamp, required this.isDown});

  final DateTime timestamp;
  final bool isDown;
}

/// 捕获左键/落笔事件的统一接口，用于 AFK 判定。
abstract class StrokeActivityTracker {
  Stream<StrokeEvent> get strokes;

  void dispose();
}

class _NoopStrokeActivityTracker implements StrokeActivityTracker {
  @override
  Stream<StrokeEvent> get strokes => const Stream<StrokeEvent>.empty();

  @override
  void dispose() {}
}

class _MacOsStrokeActivityTracker implements StrokeActivityTracker {
  _MacOsStrokeActivityTracker() {
    if (kDebugMode) {
      debugPrint(
        '[StrokeActivityTracker] _MacOsStrokeActivityTracker subscribing to EventChannel',
      );
    }
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (error) {
        if (kDebugMode) {
          debugPrint('[StrokeActivityTracker][macOS] error: $error');
        }
      },
    );
  }

  static const _eventChannel = EventChannel('ringotrack/stroke_events');

  final _controller = StreamController<StrokeEvent>.broadcast();
  StreamSubscription<dynamic>? _subscription;

  @override
  Stream<StrokeEvent> get strokes => _controller.stream;

  void _handleEvent(dynamic event) {
    if (event is Map) {
      final tsMillis = event['timestamp'] as num?;
      final isDown = event['isDown'] as bool? ?? true;
      if (tsMillis == null) return;

      final ts = DateTime.fromMillisecondsSinceEpoch(
        tsMillis.toInt(),
        isUtc: false,
      );

      if (kDebugMode) {
        debugPrint(
          '[StrokeActivityTracker][macOS] stroke at ${ts.toIso8601String()} '
          'isDown=$isDown',
        );
      }

      _controller.add(StrokeEvent(timestamp: ts, isDown: isDown));
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

/// Windows 侧通过 FFI 轮询 native 维护的 last_left_click_millis。
class _WindowsStrokeActivityTracker implements StrokeActivityTracker {
  _WindowsStrokeActivityTracker()
    : _initStrokeHook = _loadInitFunction(),
      _getLastStrokeMillis = _loadGetLastStrokeFunction(),
      _getIsLeftButtonDown = _loadIsButtonDownFunction() {
    if (_initStrokeHook == null ||
        _getLastStrokeMillis == null ||
        _getIsLeftButtonDown == null) {
      AppLogService.instance.logError(
        _logTag,
        'native stroke hook not available; tracker disabled',
      );
      return;
    }

    _initStrokeHook();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _pollOnce());
  }

  static const _logTag = 'stroke_tracker_windows';

  final RtInitStrokeHookDart? _initStrokeHook;
  final RtGetLastStrokeMillisDart? _getLastStrokeMillis;
  final RtIsLeftButtonDownDart? _getIsLeftButtonDown;

  final _controller = StreamController<StrokeEvent>.broadcast();
  Timer? _timer;
  int _lastSeenMillis = 0;
  bool _lastButtonDown = false;

  static RtInitStrokeHookDart? _loadInitFunction() {
    try {
      final lib = ffi.DynamicLibrary.process();
      return lib.lookupFunction<RtInitStrokeHookNative, RtInitStrokeHookDart>(
        'rt_init_stroke_hook',
      );
    } catch (e, st) {
      AppLogService.instance.logError(
        _logTag,
        'lookup rt_init_stroke_hook failed: $e\n$st',
      );
      return null;
    }
  }

  static RtGetLastStrokeMillisDart? _loadGetLastStrokeFunction() {
    try {
      final lib = ffi.DynamicLibrary.process();
      return lib.lookupFunction<
        RtGetLastStrokeMillisNative,
        RtGetLastStrokeMillisDart
      >('rt_get_last_left_click_millis');
    } catch (e, st) {
      AppLogService.instance.logError(
        _logTag,
        'lookup rt_get_last_left_click_millis failed: $e\n$st',
      );
      return null;
    }
  }

  static RtIsLeftButtonDownDart? _loadIsButtonDownFunction() {
    try {
      final lib = ffi.DynamicLibrary.process();
      return lib
          .lookupFunction<RtIsLeftButtonDownNative, RtIsLeftButtonDownDart>(
            'rt_is_left_button_down',
          );
    } catch (e, st) {
      AppLogService.instance.logError(
        _logTag,
        'lookup rt_is_left_button_down failed: $e\n$st',
      );
      return null;
    }
  }

  @override
  Stream<StrokeEvent> get strokes => _controller.stream;

  void _pollOnce() {
    final getter = _getLastStrokeMillis;
    final buttonGetter = _getIsLeftButtonDown;
    if (getter == null || buttonGetter == null) return;

    int millis;
    bool isDown;
    try {
      millis = getter();
      isDown = buttonGetter() != 0;
    } catch (e, st) {
      AppLogService.instance.logError(_logTag, 'poll error: $e\n$st');
      return;
    }

    if (millis == 0 && !isDown) {
      return;
    }

    final hasNewTimestamp = millis != 0 && millis != _lastSeenMillis;
    final buttonChanged = isDown != _lastButtonDown;

    if (!hasNewTimestamp && !buttonChanged) {
      return;
    }

    _lastSeenMillis = millis == 0 ? _lastSeenMillis : millis;
    _lastButtonDown = isDown;

    final tsMillis = millis == 0
        ? DateTime.now().millisecondsSinceEpoch
        : millis;
    final ts = DateTime.fromMillisecondsSinceEpoch(tsMillis, isUtc: false);
    if (kDebugMode) {
      debugPrint(
        '[StrokeActivityTracker][Windows] stroke state ts=${ts.toIso8601String()} isDown=$isDown',
      );
    }
    _controller.add(StrokeEvent(timestamp: ts, isDown: isDown));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

StrokeActivityTracker createStrokeActivityTracker() {
  if (kDebugMode) {
    debugPrint(
      '[StrokeActivityTracker] createStrokeActivityTracker: '
      'Platform.isMacOS=${Platform.isMacOS} Platform.isWindows=${Platform.isWindows}',
    );
  }

  if (Platform.isMacOS) {
    return _MacOsStrokeActivityTracker();
  }

  if (Platform.isWindows) {
    return _WindowsStrokeActivityTracker();
  }

  return _NoopStrokeActivityTracker();
}
