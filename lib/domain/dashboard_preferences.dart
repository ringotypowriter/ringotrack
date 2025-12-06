import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';

/// 热力图时间范围模式。
/// - calendarYear: 当年 1/1 ~ 12/31
/// - rolling12Months: 最近 12 个月，右侧对齐当前月
enum HeatmapRangeMode { calendarYear, rolling12Months }

class DashboardPreferences {
  const DashboardPreferences({
    this.heatmapRangeMode = HeatmapRangeMode.calendarYear,
    this.enableGlassEffect = false,
  });

  final HeatmapRangeMode heatmapRangeMode;

  /// 是否启用毛玻璃效果（macOS / Windows 支持）。
  final bool enableGlassEffect;

  /// 当前平台是否实际使用毛玻璃效果。
  /// 只有 macOS / Windows 且 enableGlassEffect 为 true 时才生效。
  bool get useGlassEffect =>
      (Platform.isMacOS || Platform.isWindows) && enableGlassEffect;

  DashboardPreferences copyWith({
    HeatmapRangeMode? heatmapRangeMode,
    bool? enableGlassEffect,
  }) {
    return DashboardPreferences(
      heatmapRangeMode: heatmapRangeMode ?? this.heatmapRangeMode,
      enableGlassEffect: enableGlassEffect ?? this.enableGlassEffect,
    );
  }
}

class DashboardPreferencesRepository {
  static const _keyRangeMode = 'ringotrack.dashboard.heatmapRangeMode';
  static const _keyGlassEffect = 'ringotrack.dashboard.enableGlassEffect';

  Future<DashboardPreferences> load() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getString(_keyRangeMode);
    final mode = HeatmapRangeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => HeatmapRangeMode.calendarYear,
    );
    final enableGlass = sp.getBool(_keyGlassEffect) ?? false;
    return DashboardPreferences(
      heatmapRangeMode: mode,
      enableGlassEffect: enableGlass,
    );
  }

  Future<void> save(DashboardPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyRangeMode, prefs.heatmapRangeMode.name);
    await sp.setBool(_keyGlassEffect, prefs.enableGlassEffect);
  }
}
