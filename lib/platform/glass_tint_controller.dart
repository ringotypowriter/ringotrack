import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef _RtSetGlassTintNative = ffi.Int32 Function(
  ffi.Uint8 r,
  ffi.Uint8 g,
  ffi.Uint8 b,
);
typedef _RtSetGlassTintDart = int Function(int r, int g, int b);

typedef _RtResetGlassTintNative = ffi.Int32 Function();
typedef _RtResetGlassTintDart = int Function();

/// 毛玻璃 tint 颜色控制器（macOS / Windows）
class GlassTintController {
  GlassTintController._(this._setTintFn, this._resetTintFn);

  static final GlassTintController instance = GlassTintController._create();

  final _RtSetGlassTintDart? _setTintFn;
  final _RtResetGlassTintDart? _resetTintFn;

  static GlassTintController _create() {
    // Windows: 通过 FFI 调用 runner 导出的 C 接口。
    if (Platform.isWindows) {
      try {
        final lib = ffi.DynamicLibrary.process();
        final setFn = lib
            .lookupFunction<_RtSetGlassTintNative, _RtSetGlassTintDart>(
              'rt_set_glass_tint',
            );
        final resetFn = lib
            .lookupFunction<_RtResetGlassTintNative, _RtResetGlassTintDart>(
              'rt_reset_glass_tint',
            );
        return GlassTintController._(setFn, resetFn);
      } catch (e, st) {
        debugPrint(
          'GlassTintController: Windows FFI lookup failed: $e\n$st',
        );
        return GlassTintController._(null, null);
      }
    }

    // 其他平台（包含 macOS，使用 MethodChannel 实现）。
    return GlassTintController._(null, null);
  }

  static const MethodChannel _channel =
      MethodChannel('ringotrack/glass_tint');

  /// 当前平台是否支持毛玻璃 tint 控制（macOS / Windows）
  bool get isSupported {
    if (Platform.isMacOS) {
      return true;
    }
    if (Platform.isWindows) {
      return _setTintFn != null && _resetTintFn != null;
    }
    return false;
  }

  /// 设置毛玻璃 tint 颜色
  Future<bool> setTintColor(Color color) async {
    if (!isSupported) return false;

    // macOS: 通过 MethodChannel 调用 MainFlutterWindow 上的实现。
    if (Platform.isMacOS) {
      try {
        final result = await _channel.invokeMethod<bool>('setTintColor', {
          'r': color.red / 255.0,
          'g': color.green / 255.0,
          'b': color.blue / 255.0,
        });
        return result ?? false;
      } catch (e, st) {
        debugPrint('GlassTintController.setTintColor(macOS) error: $e\n$st');
        return false;
      }
    }

    // Windows: 通过 FFI 调用 rt_set_glass_tint。
    if (Platform.isWindows) {
      final fn = _setTintFn;
      if (fn == null) return false;
      try {
        final code = fn(color.red, color.green, color.blue);
        return code != 0;
      } catch (e, st) {
        debugPrint('GlassTintController.setTintColor(Windows) error: $e\n$st');
        return false;
      }
    }

    return false;
  }

  /// 重置为默认白色 tint
  Future<bool> resetTintColor() async {
    if (!isSupported) return false;

    // macOS: 通过 MethodChannel 调用 MainFlutterWindow 上的实现。
    if (Platform.isMacOS) {
      try {
        final result = await _channel.invokeMethod<bool>('resetTintColor');
        return result ?? false;
      } catch (e, st) {
        debugPrint(
          'GlassTintController.resetTintColor(macOS) error: $e\n$st',
        );
        return false;
      }
    }

    // Windows: 通过 FFI 调用 rt_reset_glass_tint。
    if (Platform.isWindows) {
      final fn = _resetTintFn;
      if (fn == null) return false;
      try {
        final code = fn();
        return code != 0;
      } catch (e, st) {
        debugPrint(
          'GlassTintController.resetTintColor(Windows) error: $e\n$st',
        );
        return false;
      }
    }

    return false;
  }
}
