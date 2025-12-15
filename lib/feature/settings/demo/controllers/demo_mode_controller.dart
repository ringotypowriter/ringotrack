import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 控制是否启用调试用的示例数据模式。
class DemoModeController extends Notifier<bool> {
  @override
  bool build() => false;

  /// 切换示例数据状态，仅在调试模式生效。
  void toggleDemoMode() {
    if (!kDebugMode) {
      return;
    }
    state = !state;
  }

  /// 强制关闭示例数据模式（用于切换回真实数据时）。
  void disable() {
    state = false;
  }
}
