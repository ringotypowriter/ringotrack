import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringotrack/domain/dashboard_preferences.dart';

typedef _RtSetGlassTintNative =
    ffi.Int32 Function(ffi.Uint8 r, ffi.Uint8 g, ffi.Uint8 b);
typedef _RtSetGlassTintDart = int Function(int r, int g, int b);

typedef _RtResetGlassTintNative = ffi.Int32 Function();
typedef _RtResetGlassTintDart = int Function();

typedef _RtDisableGlassNative = ffi.Int32 Function();
typedef _RtDisableGlassDart = int Function();

/// 毛玻璃 tint 颜色控制器（macOS / Windows）
class GlassTintController {
  GlassTintController._(this._setTintFn, this._resetTintFn, this._disableGlassFn);

  static final GlassTintController instance = GlassTintController._create();

  final _RtSetGlassTintDart? _setTintFn;
  final _RtResetGlassTintDart? _resetTintFn;
  final _RtDisableGlassDart? _disableGlassFn;

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
        final disableFn = lib
            .lookupFunction<_RtDisableGlassNative, _RtDisableGlassDart>(
              'rt_disable_glass',
            );
        return GlassTintController._(setFn, resetFn, disableFn);
      } catch (e, st) {
        debugPrint('GlassTintController: Windows FFI lookup failed: $e\n$st');
        return GlassTintController._(null, null, null);
      }
    }

    // 其他平台（包含 macOS，使用 MethodChannel 实现）。
    return GlassTintController._(null, null, null);
  }

  static const MethodChannel _channel = MethodChannel('ringotrack/glass_tint');

  /// Windows 平台：检查用户是否在 preference 中启用了玻璃效果。
  /// 用于避免在页面切换时意外启用玻璃效果。
  Future<bool> _isGlassEnabledInPrefs() async {
    try {
      final repo = DashboardPreferencesRepository();
      final prefs = await repo.load();
      return prefs.enableGlassEffect;
    } catch (e) {
      debugPrint('GlassTintController._isGlassEnabledInPrefs error: $e');
      return false;
    }
  }

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
  /// Windows 平台会先检查 preference，如果用户禁用了玻璃效果则不执行。
  Future<bool> setTintColor(Color color) async {
    if (!isSupported) return false;

    // macOS: 通过 MethodChannel 调用 MainFlutterWindow 上的实现。
    if (Platform.isMacOS) {
      try {
        final result = await _channel.invokeMethod<bool>('setTintColor', {
          'r': (color.r * 255.0).round().clamp(0, 255) / 255.0,
          'g': (color.g * 255.0).round().clamp(0, 255) / 255.0,
          'b': (color.b * 255.0).round().clamp(0, 255) / 255.0,
        });
        return result ?? false;
      } catch (e, st) {
        debugPrint('GlassTintController.setTintColor(macOS) error: $e\n$st');
        return false;
      }
    }

    // Windows: 通过 FFI 调用 rt_set_glass_tint。
    // 先检查 preference，如果用户禁用了玻璃效果则不执行，避免意外启用玻璃。
    if (Platform.isWindows) {
      if (!await _isGlassEnabledInPrefs()) return false;

      final fn = _setTintFn;
      if (fn == null) return false;
      try {
        final code = fn(
          (color.r * 255.0).round().clamp(0, 255),
          (color.g * 255.0).round().clamp(0, 255),
          (color.b * 255.0).round().clamp(0, 255),
        );
        return code != 0;
      } catch (e, st) {
        debugPrint('GlassTintController.setTintColor(Windows) error: $e\n$st');
        return false;
      }
    }

    return false;
  }

  /// 重置为默认白色 tint
  /// Windows 平台会先检查 preference，如果用户禁用了玻璃效果则不执行。
  Future<bool> resetTintColor() async {
    if (!isSupported) return false;

    // macOS: 通过 MethodChannel 调用 MainFlutterWindow 上的实现。
    if (Platform.isMacOS) {
      try {
        final result = await _channel.invokeMethod<bool>('resetTintColor');
        return result ?? false;
      } catch (e, st) {
        debugPrint('GlassTintController.resetTintColor(macOS) error: $e\n$st');
        return false;
      }
    }

    // Windows: 通过 FFI 调用 rt_reset_glass_tint。
    // 先检查 preference，如果用户禁用了玻璃效果则不执行，避免意外启用玻璃。
    if (Platform.isWindows) {
      if (!await _isGlassEnabledInPrefs()) return false;

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

  /// 完全禁用毛玻璃效果（仅 Windows 支持，macOS 使用不同的机制）
  Future<bool> disableGlass() async {
    // Windows: 通过 FFI 调用 rt_disable_glass。
    if (Platform.isWindows) {
      final fn = _disableGlassFn;
      if (fn == null) return false;
      try {
        final code = fn();
        return code != 0;
      } catch (e, st) {
        debugPrint(
          'GlassTintController.disableGlass(Windows) error: $e\n$st',
        );
        return false;
      }
    }

    // macOS: 通过 MethodChannel 调用 disableGlass。
    if (Platform.isMacOS) {
      try {
        final result = await _channel.invokeMethod<bool>('disableGlass');
        return result ?? false;
      } catch (e, st) {
        debugPrint('GlassTintController.disableGlass(macOS) error: $e\n$st');
        return false;
      }
    }

    return false;
  }

  /// 启用毛玻璃效果（使用默认白色 tint）
  Future<bool> enableGlass() async {
    return resetTintColor();
  }
}
