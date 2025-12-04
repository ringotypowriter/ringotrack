import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ringotrack/domain/app_log_service.dart';
import 'package:ringotrack/domain/usage_models.dart';

/// 统一的前台应用切换事件跟踪接口
abstract class ForegroundAppTracker {
  Stream<ForegroundAppEvent> get events;
}

class _MacOsForegroundAppTracker implements ForegroundAppTracker {
  _MacOsForegroundAppTracker() {
    if (kDebugMode) {
      debugPrint(
        '[ForegroundAppTracker] _MacOsForegroundAppTracker initialized, '
        'subscribing to EventChannel',
      );
    }

    _subscription = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: _handleError,
    );
  }

  static const _eventChannel = EventChannel('ringotrack/foreground_app_events');

  final _controller = StreamController<ForegroundAppEvent>.broadcast();
  late final StreamSubscription<dynamic> _subscription;

  @override
  Stream<ForegroundAppEvent> get events => _controller.stream;

  void _handleEvent(dynamic event) {
    if (event is Map) {
      final appId = event['appId'] as String?;
      final tsMillis = event['timestamp'] as num?;
      if (appId == null || tsMillis == null) return;

      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        tsMillis.toInt(),
        isUtc: false,
      );

      if (kDebugMode) {
        debugPrint(
          '[ForegroundAppTracker] macOS event: appId=$appId '
          'timestamp=${timestamp.toIso8601String()}',
        );
      }

      _controller.add(ForegroundAppEvent(appId: appId, timestamp: timestamp));
    }
  }

  void _handleError(Object error) {
    if (kDebugMode) {
      debugPrint('[ForegroundAppTracker] error: $error');
    }
  }
}

class _NoopForegroundAppTracker implements ForegroundAppTracker {
  @override
  Stream<ForegroundAppEvent> get events => const Stream.empty();
}

// 与 Windows C 侧 RtForegroundAppInfo 对齐的 FFI 结构体
class _RtForegroundAppInfo extends ffi.Struct {
  @ffi.Uint64()
  external int timestampMillis;

  @ffi.Uint32()
  external int pid;

  @ffi.Int32()
  external int isError;

  @ffi.Int32()
  external int errorCode;

  @ffi.Array.multi([260])
  external ffi.Array<ffi.Uint16> exePath;

  @ffi.Array.multi([260])
  external ffi.Array<ffi.Uint16> windowTitle;
}

typedef _RtGetForegroundAppNative =
    ffi.Pointer<_RtForegroundAppInfo> Function();
typedef _RtGetForegroundAppDart =
    ffi.Pointer<_RtForegroundAppInfo> Function();

class _WindowsForegroundAppTracker implements ForegroundAppTracker {
  _WindowsForegroundAppTracker() {
    if (kDebugMode) {
      debugPrint('[ForegroundAppTracker] using Windows implementation');
    }
    _startPolling();
  }

  static const _logTag = 'foreground_tracker_windows';

  static final ffi.DynamicLibrary _lib = ffi.DynamicLibrary.process();

  static final _RtGetForegroundAppDart _rtGetForegroundApp = _lib
      .lookupFunction<_RtGetForegroundAppNative, _RtGetForegroundAppDart>(
    'rt_get_foreground_app',
  );

  final _controller = StreamController<ForegroundAppEvent>.broadcast();
  Timer? _timer;

  String? _lastAppId;
  int? _lastPid;

  @override
  Stream<ForegroundAppEvent> get events => _controller.stream;

  void _startPolling() {
    // 简单使用固定轮询间隔，后续如有需要可以抽参数
    const interval = Duration(seconds: 1);
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      _pollOnce();
    });
  }

  void _pollOnce() {
    try {
      final ptr = _rtGetForegroundApp();
      if (ptr == ffi.Pointer<_RtForegroundAppInfo>.fromAddress(0)) {
        AppLogService.instance.logError(
          _logTag,
          'rt_get_foreground_app returned null pointer',
        );
        return;
      }

      final info = ptr.ref;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        info.timestampMillis,
        isUtc: false,
      );

      final fullPath = _utf16ArrayToString(info.exePath);
      final title = _utf16ArrayToString(info.windowTitle);
      final pid = info.pid;

      final appId = _extractAppIdFromPath(fullPath);

      final baseLog =
          'ts=${timestamp.toIso8601String()} pid=$pid appId=$appId '
          'path="$fullPath" title="$title" '
          'isError=${info.isError} errorCode=${info.errorCode}';

      AppLogService.instance.logDebug(_logTag, baseLog);

      if (appId.isEmpty) {
        // 没有拿到可用的 exe 名称，不发事件，只记录日志。
        return;
      }

      if (_lastAppId == appId && _lastPid == pid) {
        // 前台应用未变化，不产生新的事件，避免噪音。
        return;
      }

      _lastAppId = appId;
      _lastPid = pid;

      final event = ForegroundAppEvent(appId: appId, timestamp: timestamp);
      _controller.add(event);

      AppLogService.instance.logInfo(
        _logTag,
        'foreground changed -> appId=$appId pid=$pid',
      );
    } catch (e, st) {
      AppLogService.instance.logError(
        _logTag,
        'poll error: $e\n$st',
      );
      if (kDebugMode) {
        debugPrint('[ForegroundAppTracker][Windows] poll error: $e');
      }
    }
  }

  String _extractAppIdFromPath(String fullPath) {
    if (fullPath.isEmpty) return '';

    // Windows 路径分隔符可能包含 \\ 或 /
    final normalized = fullPath.replaceAll('\\\', '/');
    final index = normalized.lastIndexOf('/');
    final fileName = index >= 0 ? normalized.substring(index + 1) : normalized;

    if (fileName.isEmpty) return '';
    return fileName.toLowerCase();
  }

  String _utf16ArrayToString(ffi.Array<ffi.Uint16> array) {
    final codeUnits = <int>[];
    for (var i = 0; i < 260; i++) {
      final unit = array[i];
      if (unit == 0) break;
      codeUnits.add(unit);
    }
    return String.fromCharCodes(codeUnits);
  }
}

ForegroundAppTracker createForegroundAppTracker() {
  if (kDebugMode) {
    debugPrint(
      '[ForegroundAppTracker] createForegroundAppTracker: '
      'Platform.isMacOS=${Platform.isMacOS} '
      'Platform.isWindows=${Platform.isWindows}',
    );
  }

  if (Platform.isMacOS) {
    if (kDebugMode) {
      debugPrint('[ForegroundAppTracker] using macOS implementation');
    }
    return _MacOsForegroundAppTracker();
  }

  if (Platform.isWindows) {
    return _WindowsForegroundAppTracker();
  }

  if (kDebugMode) {
    debugPrint('[ForegroundAppTracker] using noop implementation');
  }

  return _NoopForegroundAppTracker();
}
