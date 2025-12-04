import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum AppPlatform {
  macos,
  windows,
  other,
}

class AppIdentifier {
  const AppIdentifier({
    required this.platform,
    required this.value,
  });

  final AppPlatform platform;
  final String value;

  Map<String, Object?> toJson() => {
        'platform': platform.name,
        'value': value,
      };

  factory AppIdentifier.fromJson(Map<String, Object?> json) {
    final platformName = json['platform'] as String? ?? 'other';
    final platform = AppPlatform.values.firstWhere(
      (p) => p.name == platformName,
      orElse: () => AppPlatform.other,
    );
    return AppIdentifier(
      platform: platform,
      value: (json['value'] as String?) ?? '',
    );
  }
}

class TrackedApp {
  const TrackedApp({
    required this.logicalId,
    required this.displayName,
    required this.ids,
    this.iconAsset,
  });

  final String logicalId;
  final String displayName;
  final String? iconAsset;
  final List<AppIdentifier> ids;

  Map<String, Object?> toJson() => {
        'logicalId': logicalId,
        'displayName': displayName,
        'iconAsset': iconAsset,
        'ids': ids.map((e) => e.toJson()).toList(),
      };

  factory TrackedApp.fromJson(Map<String, Object?> json) {
    final idsJson = json['ids'] as List<dynamic>? ?? <dynamic>[];
    return TrackedApp(
      logicalId: (json['logicalId'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? '',
      iconAsset: json['iconAsset'] as String?,
      ids: idsJson
          .whereType<Map<String, Object?>>()
          .map(AppIdentifier.fromJson)
          .toList(),
    );
  }

  TrackedApp addIdentifier(AppIdentifier id) {
    final existing = ids.map((e) => e.value.toLowerCase()).toSet();
    if (existing.contains(id.value.toLowerCase())) {
      return this;
    }
    return TrackedApp(
      logicalId: logicalId,
      displayName: displayName,
      iconAsset: iconAsset,
      ids: [...ids, id],
    );
  }
}

class DrawingAppPreferences {
  const DrawingAppPreferences({required this.trackedApps});

  final List<TrackedApp> trackedApps;
}

// 常见绘画/美术软件的默认结构化列表，可按需扩充。
const List<TrackedApp> defaultTrackedApps = [
  TrackedApp(
    logicalId: 'photoshop',
    displayName: 'Adobe Photoshop',
    iconAsset: null,
    ids: [
      AppIdentifier(
        platform: AppPlatform.macos,
        value: 'com.adobe.photoshop',
      ),
      AppIdentifier(
        platform: AppPlatform.windows,
        value: 'photoshop.exe',
      ),
    ],
  ),
  TrackedApp(
    logicalId: 'illustrator',
    displayName: 'Adobe Illustrator',
    iconAsset: null,
    ids: [
      AppIdentifier(
        platform: AppPlatform.macos,
        value: 'com.adobe.illustrator',
      ),
      AppIdentifier(
        platform: AppPlatform.windows,
        value: 'illustrator.exe',
      ),
    ],
  ),
  TrackedApp(
    logicalId: 'clipstudio',
    displayName: 'CLIP STUDIO PAINT',
    iconAsset: null,
    ids: [
      AppIdentifier(
        platform: AppPlatform.macos,
        value: 'jp.co.celsys.clipstudiopaint',
      ),
      AppIdentifier(
        platform: AppPlatform.windows,
        value: 'CLIPStudioPaint.exe',
      ),
    ],
  ),
  TrackedApp(
    logicalId: 'udmpaint',
    displayName: '优动漫',
    iconAsset: null,
    ids: [
      AppIdentifier(
        platform: AppPlatform.macos,
        value: 'xmunicorn.udongman.paint',
      ),
      AppIdentifier(
        platform: AppPlatform.windows,
        value: 'UDMPaintPRO.exe',
      ),
      AppIdentifier(
        platform: AppPlatform.windows,
        value: 'UDMPaintEX.exe',
      ),
    ],
  ),
  TrackedApp(
    logicalId: 'figma',
    displayName: 'Figma',
    iconAsset: null,
    ids: [
      AppIdentifier(
        platform: AppPlatform.macos,
        value: 'com.figma.Desktop',
      ),
      AppIdentifier(
        platform: AppPlatform.windows,
        value: 'Figma.exe',
      ),
    ],
  ),
  TrackedApp(
    logicalId: 'sai',
    displayName: 'SAI',
    iconAsset: null,
    ids: [
      AppIdentifier(
        platform: AppPlatform.windows,
        value: 'sai.exe',
      ),
    ],
  ),
  TrackedApp(
    logicalId: 'sai2',
    displayName: 'SAI2',
    iconAsset: null,
    ids: [
      AppIdentifier(
        platform: AppPlatform.windows,
        value: 'sai2.exe',
      ),
    ],
  ),
];

abstract class DrawingAppPreferencesRepository {
  Future<DrawingAppPreferences> load();

  Future<void> save(DrawingAppPreferences prefs);
}

class SharedPrefsDrawingAppPreferencesRepository
    implements DrawingAppPreferencesRepository {
  static const _trackedAppsKeyV2 = 'ringotrack.trackedApps.v2';

  @override
  Future<DrawingAppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_trackedAppsKeyV2);

    if (jsonString == null || jsonString.isEmpty) {
      return const DrawingAppPreferences(trackedApps: defaultTrackedApps);
    }

    try {
      final decoded = json.decode(jsonString) as List<dynamic>;
      final apps = decoded
          .whereType<Map<String, Object?>>()
          .map(TrackedApp.fromJson)
          .where((app) => app.displayName.isNotEmpty)
          .toList();

      if (apps.isEmpty) {
        return const DrawingAppPreferences(trackedApps: defaultTrackedApps);
      }

      return DrawingAppPreferences(trackedApps: apps);
    } catch (_) {
      return const DrawingAppPreferences(trackedApps: defaultTrackedApps);
    }
  }

  @override
  Future<void> save(DrawingAppPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    final serialized = json.encode(
      prefs.trackedApps.map((e) => e.toJson()).toList(),
    );
    await sp.setString(_trackedAppsKeyV2, serialized);
  }
}

/// 构造用于 UsageAggregator 的过滤闭包。
bool Function(String appId) buildAppFilter(DrawingAppPreferences prefs) {
  final trackedIds = <String>{};
  for (final app in prefs.trackedApps) {
    for (final id in app.ids) {
      trackedIds.add(id.value.toLowerCase());
    }
  }

  return (appId) => trackedIds.contains(appId.toLowerCase());
}
