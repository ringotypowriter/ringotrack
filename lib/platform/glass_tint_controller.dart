import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// macOS 毛玻璃 tint 颜色控制器
class GlassTintController {
  GlassTintController._();

  static final GlassTintController instance = GlassTintController._();

  static const MethodChannel _channel =
      MethodChannel('ringotrack/glass_tint');

  /// 当前平台是否支持毛玻璃 tint 控制（仅 macOS）
  bool get isSupported => Platform.isMacOS;

  /// 设置毛玻璃 tint 颜色
  Future<bool> setTintColor(Color color) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>('setTintColor', {
        'r': color.red / 255.0,
        'g': color.green / 255.0,
        'b': color.blue / 255.0,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('GlassTintController.setTintColor error: $e');
      return false;
    }
  }

  /// 重置为默认白色 tint
  Future<bool> resetTintColor() async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>('resetTintColor');
      return result ?? false;
    } catch (e) {
      debugPrint('GlassTintController.resetTintColor error: $e');
      return false;
    }
  }
}
