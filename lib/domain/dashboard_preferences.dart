import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';

/// 热力图时间范围模式。
/// - calendarYear: 当年 1/1 ~ 12/31
/// - rolling12Months: 最近 12 个月，右侧对齐当前月
enum HeatmapRangeMode { calendarYear, rolling12Months }

/// 以哪一天作为一周的起点。
enum WeekStartMode { sunday, monday }

class DashboardPreferences {
  const DashboardPreferences({
    this.heatmapRangeMode = HeatmapRangeMode.calendarYear,
    this.enableGlassEffect = false,
    this.weekStartMode = WeekStartMode.monday,
  });

  final HeatmapRangeMode heatmapRangeMode;

  /// 是否启用毛玻璃效果（macOS / Windows 支持）。
  final bool enableGlassEffect;

  /// 一周从哪一天开始。
  final WeekStartMode weekStartMode;

  /// 当前平台是否实际使用毛玻璃效果。
  /// 只有 macOS / Windows 且 enableGlassEffect 为 true 时才生效。
  bool get useGlassEffect =>
      (Platform.isMacOS || Platform.isWindows) && enableGlassEffect;

  DashboardPreferences copyWith({
    HeatmapRangeMode? heatmapRangeMode,
    bool? enableGlassEffect,
    WeekStartMode? weekStartMode,
  }) {
    return DashboardPreferences(
      heatmapRangeMode: heatmapRangeMode ?? this.heatmapRangeMode,
      enableGlassEffect: enableGlassEffect ?? this.enableGlassEffect,
      weekStartMode: weekStartMode ?? this.weekStartMode,
    );
  }
}

class DashboardPreferencesRepository {
  static const _keyRangeMode = 'ringotrack.dashboard.heatmapRangeMode';
  static const _keyGlassEffect = 'ringotrack.dashboard.enableGlassEffect';
  // Windows 平台：待生效的玻璃效果设置，下次启动时应用
  static const _keyGlassEffectPending = 'ringotrack.dashboard.enableGlassEffect.pending';
  
  static const _keyWeekStartMode = 'ringotrack.dashboard.weekStartMode';

  Future<DashboardPreferences> load() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getString(_keyRangeMode);
    final mode = HeatmapRangeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => HeatmapRangeMode.calendarYear,
    );
    final enableGlass = sp.getBool(_keyGlassEffect) ?? false;
    final savedWeekStart = sp.getString(_keyWeekStartMode);
    final weekStartMode = WeekStartMode.values.firstWhere(
      (m) => m.name == savedWeekStart,
      orElse: () => const DashboardPreferences().weekStartMode,
    );
    return DashboardPreferences(
      heatmapRangeMode: mode,
      enableGlassEffect: enableGlass,
      weekStartMode: weekStartMode,
    );
  }

  Future<void> save(DashboardPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyRangeMode, prefs.heatmapRangeMode.name);
    await sp.setBool(_keyGlassEffect, prefs.enableGlassEffect);
    await sp.setString(_keyWeekStartMode, prefs.weekStartMode.name);
  }

  /// Windows 平台：设置待生效的玻璃效果值（下次启动时应用）
  Future<void> setGlassEffectPending(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_keyGlassEffectPending, enabled);
  }

  /// Windows 平台：获取待生效的玻璃效果值
  /// 返回 null 表示没有待生效的设置
  Future<bool?> getGlassEffectPending() async {
    final sp = await SharedPreferences.getInstance();
    if (!sp.containsKey(_keyGlassEffectPending)) return null;
    return sp.getBool(_keyGlassEffectPending);
  }

  /// Windows 平台：启动时调用，将 pending 值应用到实际设置
  /// 返回最终的 enableGlassEffect 值
  Future<bool> applyPendingGlassEffect() async {
    final sp = await SharedPreferences.getInstance();
    final pending = sp.getBool(_keyGlassEffectPending);
    if (pending != null) {
      // 将 pending 值应用到实际设置
      await sp.setBool(_keyGlassEffect, pending);
      // 清除 pending
      await sp.remove(_keyGlassEffectPending);
      return pending;
    }
    // 没有 pending，返回当前值
    return sp.getBool(_keyGlassEffect) ?? false;
  }
}
