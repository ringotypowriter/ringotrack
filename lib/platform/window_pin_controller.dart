import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ringotrack/domain/app_log_service.dart';

typedef _RtEnterPinnedModeNative = ffi.Int32 Function();
typedef _RtEnterPinnedModeDart = int Function();

typedef _RtExitPinnedModeNative = ffi.Int32 Function();
typedef _RtExitPinnedModeDart = int Function();

/// 控制窗口在 Windows 上的置顶 / 取消置顶行为。
///
/// 通过 FFI 调用 runner 进程中导出的 Win32 函数，实现：
/// - 缩放到预设的小尺寸，并置顶到前台（但不抢占焦点）
/// - 恢复到原先的窗口位置和大小，并取消置顶
final class WindowPinController {
  WindowPinController._(this._enterPinnedMode, this._exitPinnedMode);

  static const _logTag = 'window_pin_windows';

  static final WindowPinController instance = WindowPinController._create();

  final _RtEnterPinnedModeDart? _enterPinnedMode;
  final _RtExitPinnedModeDart? _exitPinnedMode;

  static WindowPinController _create() {
    if (!Platform.isWindows) {
      if (kDebugMode) {
        debugPrint('[WindowPinController] non-Windows platform, using noop');
      }
      return WindowPinController._(null, null);
    }

    try {
      final lib = ffi.DynamicLibrary.process();
      final enterFn = lib.lookupFunction<
          _RtEnterPinnedModeNative, _RtEnterPinnedModeDart>(
        'rt_enter_pinned_mode',
      );
      final exitFn = lib.lookupFunction<
          _RtExitPinnedModeNative, _RtExitPinnedModeDart>(
        'rt_exit_pinned_mode',
      );

      if (kDebugMode) {
        debugPrint('[WindowPinController] FFI functions resolved');
      }

      return WindowPinController._(enterFn, exitFn);
    } catch (e, st) {
      AppLogService.instance.logError(
        _logTag,
        'lookup native pin functions failed: $e\n$st',
      );
      if (kDebugMode) {
        debugPrint('[WindowPinController] lookup failed: $e');
      }
      return WindowPinController._(null, null);
    }
  }

  bool get isSupported => _enterPinnedMode != null && _exitPinnedMode != null;

  Future<bool> enterPinnedMode() async {
    final enterFn = _enterPinnedMode;
    if (enterFn == null) {
      return false;
    }

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

  Future<bool> exitPinnedMode() async {
    final exitFn = _exitPinnedMode;
    if (exitFn == null) {
      return false;
    }

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
}

