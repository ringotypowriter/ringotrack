import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ringotrack/feature/logging/services/app_log_service.dart';
import 'package:ringotrack/feature/usage/models/usage_models.dart';

/// 统一的前台应用切换事件跟踪接口
abstract class ForegroundAppTracker {
  Stream<ForegroundAppEvent> get events;

  /// 清理资源，取消订阅和定时器
  void dispose();
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
  StreamSubscription<dynamic>? _subscription;

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

      AppLogService.instance.logInfo(
        'foreground_tracker_macos',
        'appId=$appId timestamp=${timestamp.toIso8601String()}',
      );

      _controller.add(ForegroundAppEvent(appId: appId, timestamp: timestamp));
    }
  }

  void _handleError(Object error) {
    if (kDebugMode) {
      debugPrint('[ForegroundAppTracker] error: $error');
    }
    AppLogService.instance.logError(
      'foreground_tracker_macos',
      'error: $error',
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

class _NoopForegroundAppTracker implements ForegroundAppTracker {
  @override
  Stream<ForegroundAppEvent> get events => const Stream.empty();

  @override
  void dispose() {
    // No resources to dispose
  }
}

// 与 Windows C 侧 RtForegroundAppInfo 对齐的 FFI 结构体
final class _RtForegroundAppInfo extends ffi.Struct {
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
typedef _RtGetForegroundAppDart = ffi.Pointer<_RtForegroundAppInfo> Function();

class _WindowsForegroundAppTracker implements ForegroundAppTracker {
  static const _logTag = 'foreground_tracker_windows';

  /// 已解析的 native 函数指针；如果为 null，则表示当前进程中没有导出
  /// `rt_get_foreground_app`，此时本跟踪器会静默失效而不是导致崩溃。
  final _RtGetForegroundAppDart? _rtGetForegroundApp;

  final _controller = StreamController<ForegroundAppEvent>.broadcast();
  Timer? _timer;

  String? _lastAppId;
  int? _lastPid;

  _WindowsForegroundAppTracker() : _rtGetForegroundApp = _loadNativeFunction() {
    if (kDebugMode) {
      debugPrint('[ForegroundAppTracker] using Windows implementation');
    }

    if (_rtGetForegroundApp == null) {
      AppLogService.instance.logError(
        _logTag,
        'rt_get_foreground_app symbol not found; Windows tracker disabled',
      );
      return;
    }

    _startPolling();
  }

  static _RtGetForegroundAppDart? _loadNativeFunction() {
    try {
      final lib = ffi.DynamicLibrary.process();
      return lib
          .lookupFunction<_RtGetForegroundAppNative, _RtGetForegroundAppDart>(
            'rt_get_foreground_app',
          );
    } catch (e, st) {
      AppLogService.instance.logError(
        _logTag,
        'lookup rt_get_foreground_app failed: $e\n$st',
      );
      if (kDebugMode) {
        debugPrint(
          '[ForegroundAppTracker][Windows] lookup rt_get_foreground_app failed: $e',
        );
      }
      return null;
    }
  }

  @override
  Stream<ForegroundAppEvent> get events => _controller.stream;

  void _startPolling() {
    const interval = Duration(seconds: 1);
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      _pollOnce();
    });
  }

  void _pollOnce() {
    final rtGetForegroundApp = _rtGetForegroundApp;
    if (rtGetForegroundApp == null) {
      // 初始化阶段未找到 native 符号，直接返回避免无意义的轮询。
      return;
    }

    try {
      final ptr = rtGetForegroundApp();
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
      AppLogService.instance.logError(_logTag, 'poll error: $e\n$st');
      if (kDebugMode) {
        debugPrint('[ForegroundAppTracker][Windows] poll error: $e');
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  String _extractAppIdFromPath(String fullPath) {
    if (fullPath.isEmpty) return '';

    // Windows 路径分隔符可能包含 \\ 或 /
    final normalized = fullPath.replaceAll('\\', '/');
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
