import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ringotrack/domain/app_log_service.dart';

typedef _RtEnterPinnedModeNative = ffi.Int32 Function();
typedef _RtEnterPinnedModeDart = int Function();

typedef _RtExitPinnedModeNative = ffi.Int32 Function();
typedef _RtExitPinnedModeDart = int Function();

typedef _RtLockWindowNative = ffi.Int32 Function();
typedef _RtLockWindowDart = int Function();

typedef _RtUnlockWindowNative = ffi.Int32 Function();
typedef _RtUnlockWindowDart = int Function();

/// 控制窗口在 Windows 上的置顶 / 取消置顶行为。
///
/// 通过 FFI 调用 runner 进程中导出的 Win32 函数，实现：
/// - 缩放到预设的小尺寸，并置顶到前台（但不抢占焦点）
/// - 恢复到原先的窗口位置和大小，并取消置顶
final class WindowPinController {
  WindowPinController._(
    this._enterPinnedMode,
    this._exitPinnedMode,
    this._lockWindow,
    this._unlockWindow,
    this._methodChannel,
  );

  static const _logTag = 'window_pin';
  static const _methodChannelName = 'ringotrack/window_pin';

  static final WindowPinController instance = WindowPinController._create();

  final _RtEnterPinnedModeDart? _enterPinnedMode;
  final _RtExitPinnedModeDart? _exitPinnedMode;
  final _RtLockWindowDart? _lockWindow;
  final _RtUnlockWindowDart? _unlockWindow;
  final MethodChannel? _methodChannel;

  static WindowPinController _create() {
    // Web 不支持桌面窗口 API，直接返回空实现。
    if (kIsWeb) {
      if (kDebugMode) {
        debugPrint('[WindowPinController] web platform, using noop');
      }
      return WindowPinController._(null, null, null, null, null);
    }

    // Windows: 通过 FFI 调用 runner 导出的 C 接口。
    if (Platform.isWindows) {
      try {
        final lib = ffi.DynamicLibrary.process();
        final enterFn = lib
            .lookupFunction<_RtEnterPinnedModeNative, _RtEnterPinnedModeDart>(
              'rt_enter_pinned_mode',
            );
        final exitFn = lib
            .lookupFunction<_RtExitPinnedModeNative, _RtExitPinnedModeDart>(
              'rt_exit_pinned_mode',
            );

        if (kDebugMode) {
          debugPrint('[WindowPinController] Windows FFI functions resolved');
        }

        final lockFn = lib
            .lookupFunction<_RtLockWindowNative, _RtLockWindowDart>(
              'rt_lock_window',
            );
        final unlockFn = lib
            .lookupFunction<_RtUnlockWindowNative, _RtUnlockWindowDart>(
              'rt_unlock_window',
            );

        if (kDebugMode) {
          debugPrint('[WindowPinController] Windows FFI functions resolved');
        }

        return WindowPinController._(enterFn, exitFn, lockFn, unlockFn, null);
      } catch (e, st) {
        AppLogService.instance.logError(
          _logTag,
          'lookup native pin functions failed: $e\n$st',
        );
        if (kDebugMode) {
          debugPrint('[WindowPinController] lookup failed: $e');
        }
        return WindowPinController._(null, null, null, null, null);
      }
    }

    // macOS: 通过 MethodChannel 调用 MainFlutterWindow 上的原生实现。
    if (Platform.isMacOS) {
      const channel = MethodChannel(_methodChannelName);
      if (kDebugMode) {
        debugPrint('[WindowPinController] macOS MethodChannel created');
      }
      return WindowPinController._(null, null, null, null, channel);
    }

    // 其他平台暂不支持。
    if (kDebugMode) {
      debugPrint('[WindowPinController] unsupported platform, using noop');
    }
    return WindowPinController._(null, null, null, null, null);
  }

  bool get isSupported {
    if (kIsWeb) {
      return false;
    }
    if (Platform.isWindows) {
      return _enterPinnedMode != null &&
          _exitPinnedMode != null &&
          _lockWindow != null &&
          _unlockWindow != null;
    }
    if (Platform.isMacOS) {
      return _methodChannel != null;
    }
    return false;
  }

  Future<bool> enterPinnedMode() async {
    if (!isSupported) {
      return false;
    }

    // Windows FFI 路径。
    final enterFn = _enterPinnedMode;
    if (Platform.isWindows && enterFn != null) {
      try {
        final result = enterFn();
        final ok = result != 0;
        if (!ok) {
          AppLogService.instance.logError(
            _logTag,
            'enterPinnedMode failed with code: $result',
          );
        }
        return ok;
      } catch (e, st) {
        AppLogService.instance.logError(
          _logTag,
          'enterPinnedMode threw: $e\n$st',
        );
        if (kDebugMode) {
          debugPrint('[WindowPinController] enterPinnedMode error: $e');
        }
        return false;
      }
    }

    // macOS MethodChannel 路径。
    final channel = _methodChannel;
    if (Platform.isMacOS && channel != null) {
      try {
        final result =
            await channel.invokeMethod<bool>('enterPinnedMode') ?? false;
        if (!result) {
          AppLogService.instance.logError(
            _logTag,
            'enterPinnedMode(macOS) returned false',
          );
        }
        return result;
      } catch (e, st) {
        AppLogService.instance.logError(
          _logTag,
          'enterPinnedMode(macOS) threw: $e\n$st',
        );
        if (kDebugMode) {
          debugPrint('[WindowPinController] enterPinnedMode macOS error: $e');
        }
        return false;
      }
    }

    return false;
  }

  Future<bool> exitPinnedMode() async {
    if (!isSupported) {
      return false;
    }

    // Windows FFI 路径。
    final exitFn = _exitPinnedMode;
    if (Platform.isWindows && exitFn != null) {
      try {
        final result = exitFn();
        final ok = result != 0;
        if (!ok) {
          AppLogService.instance.logError(
            _logTag,
            'exitPinnedMode failed with code: $result',
          );
        }
        return ok;
      } catch (e, st) {
        AppLogService.instance.logError(
          _logTag,
          'exitPinnedMode threw: $e\n$st',
        );
        if (kDebugMode) {
          debugPrint('[WindowPinController] exitPinnedMode error: $e');
        }
        return false;
      }
    }

    // macOS MethodChannel 路径。
    final channel = _methodChannel;
    if (Platform.isMacOS && channel != null) {
      try {
        final result =
            await channel.invokeMethod<bool>('exitPinnedMode') ?? false;
        if (!result) {
          AppLogService.instance.logError(
            _logTag,
            'exitPinnedMode(macOS) returned false',
          );
        }
        return result;
      } catch (e, st) {
        AppLogService.instance.logError(
          _logTag,
          'exitPinnedMode(macOS) threw: $e\n$st',
        );
        if (kDebugMode) {
          debugPrint('[WindowPinController] exitPinnedMode macOS error: $e');
        }
        return false;
      }
    }

    return false;
  }

  Future<bool> lockWindow() async {
    if (!isSupported) {
      return false;
    }

    // Windows FFI 路径。
    final lockFn = _lockWindow;
    if (Platform.isWindows && lockFn != null) {
      try {
        final result = lockFn();
        final ok = result != 0;
        if (!ok) {
          AppLogService.instance.logError(
            _logTag,
            'lockWindow failed with code: $result',
          );
        }
        return ok;
      } catch (e, st) {
        AppLogService.instance.logError(_logTag, 'lockWindow threw: $e\n$st');
        if (kDebugMode) {
          debugPrint('[WindowPinController] lockWindow error: $e');
        }
        return false;
      }
    }

    // macOS MethodChannel 路径。
    final channel = _methodChannel;
    if (Platform.isMacOS && channel != null) {
      try {
        final result = await channel.invokeMethod<bool>('lockWindow') ?? false;
        if (!result) {
          AppLogService.instance.logError(
            _logTag,
            'lockWindow(macOS) returned false',
          );
        }
        return result;
      } catch (e, st) {
        AppLogService.instance.logError(
          _logTag,
          'lockWindow(macOS) threw: $e\n$st',
        );
        if (kDebugMode) {
          debugPrint('[WindowPinController] lockWindow macOS error: $e');
        }
        return false;
      }
    }

    return false;
  }

  Future<bool> unlockWindow() async {
    if (!isSupported) {
      return false;
    }

    // Windows FFI 路径。
    final unlockFn = _unlockWindow;
    if (Platform.isWindows && unlockFn != null) {
      try {
        final result = unlockFn();
        final ok = result != 0;
        if (!ok) {
          AppLogService.instance.logError(
            _logTag,
            'unlockWindow failed with code: $result',
          );
        }
        return ok;
      } catch (e, st) {
        AppLogService.instance.logError(_logTag, 'unlockWindow threw: $e\n$st');
        if (kDebugMode) {
          debugPrint('[WindowPinController] unlockWindow error: $e');
        }
        return false;
      }
    }

    // macOS MethodChannel 路径。
    final channel = _methodChannel;
    if (Platform.isMacOS && channel != null) {
      try {
        final result =
            await channel.invokeMethod<bool>('unlockWindow') ?? false;
        if (!result) {
          AppLogService.instance.logError(
            _logTag,
            'unlockWindow(macOS) returned false',
          );
        }
        return result;
      } catch (e, st) {
        AppLogService.instance.logError(
          _logTag,
          'unlockWindow(macOS) threw: $e\n$st',
        );
        if (kDebugMode) {
          debugPrint('[WindowPinController] unlockWindow macOS error: $e');
        }
        return false;
      }
    }

    return false;
  }
}
