import 'package:shared_preferences/shared_preferences.dart';

class DrawingAppPreferences {
  const DrawingAppPreferences({required this.trackedAppIds});

  final Set<String> trackedAppIds;
}

// 常见绘画/美术软件的 bundleId / 进程名默认列表，可按需扩充。
const Set<String> defaultTrackedAppIds = {
  'com.adobe.photoshop',
  'com.adobe.illustrator',
  'jp.co.celsys.clipstudiopaint',
  'org.kde.krita',
  'net.sketchbook',
  'com.procreate.app',
  'com.autodesk.sketchbook',
};

abstract class DrawingAppPreferencesRepository {
  Future<DrawingAppPreferences> load();

  Future<void> save(DrawingAppPreferences prefs);
}

class SharedPrefsDrawingAppPreferencesRepository
    implements DrawingAppPreferencesRepository {
  static const _trackedAppsKey = 'ringotrack.trackedAppIds';

  @override
  Future<DrawingAppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_trackedAppsKey);

    if (stored == null || stored.isEmpty) {
      return const DrawingAppPreferences(
        trackedAppIds: defaultTrackedAppIds,
      );
    }

    final normalized = stored.map((e) => e.toLowerCase()).toSet();
    return DrawingAppPreferences(trackedAppIds: normalized);
  }

  @override
  Future<void> save(DrawingAppPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    final normalized = prefs.trackedAppIds.map((e) => e.toLowerCase()).toList();
    await sp.setStringList(_trackedAppsKey, normalized);
  }
}

/// 构造用于 UsageAggregator 的过滤闭包。
bool Function(String appId) buildAppFilter(DrawingAppPreferences prefs) {
  final tracked = prefs.trackedAppIds.map((e) => e.toLowerCase()).toSet();
  return (appId) => tracked.contains(appId.toLowerCase());
}
