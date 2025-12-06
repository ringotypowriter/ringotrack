import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ringotrack/app.dart';
import 'package:ringotrack/domain/dashboard_preferences.dart';
import 'package:ringotrack/platform/glass_tint_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows 平台：在启动时一次性决定是否启用玻璃效果。
  // 由于 Windows 上玻璃效果无法在运行时优雅地关闭，
  // 所以仅在启动时根据用户偏好来决定是否启用。
  if (Platform.isWindows) {
    final repo = DashboardPreferencesRepository();
    // 先应用 pending 值（如果有的话），这样 UI 层读取到的是最新的设置
    final enableGlass = await repo.applyPendingGlassEffect();
    if (enableGlass) {
      await GlassTintController.instance.enableGlass();
    }
    // 如果 enableGlassEffect 为 false，则完全不启用玻璃效果，
    // 窗口将保持默认的不透明背景。
  }

  runApp(const ProviderScope(child: RingoTrackApp()));
}
