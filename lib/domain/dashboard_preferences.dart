import 'package:shared_preferences/shared_preferences.dart';

/// 热力图时间范围模式。
/// - calendarYear: 当年 1/1 ~ 12/31
/// - rolling12Months: 最近 12 个月，右侧对齐当前月
enum HeatmapRangeMode { calendarYear, rolling12Months }

class DashboardPreferences {
  const DashboardPreferences({
    this.heatmapRangeMode = HeatmapRangeMode.calendarYear,
  });

  final HeatmapRangeMode heatmapRangeMode;
}

class DashboardPreferencesRepository {
  static const _keyRangeMode = 'ringotrack.dashboard.heatmapRangeMode';

  Future<DashboardPreferences> load() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getString(_keyRangeMode);
    final mode = HeatmapRangeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => HeatmapRangeMode.calendarYear,
    );
    return DashboardPreferences(heatmapRangeMode: mode);
  }

  Future<void> save(DashboardPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyRangeMode, prefs.heatmapRangeMode.name);
  }
}
