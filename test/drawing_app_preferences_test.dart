import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringotrack/domain/drawing_app_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DrawingAppPreferencesRepository', () {
    test('returns default tracked apps when empty store', () async {
      final repo = SharedPrefsDrawingAppPreferencesRepository();

      final prefs = await repo.load();

      // 至少要包含常见绘画软件
      expect(prefs.trackedApps.length, greaterThanOrEqualTo(3));
      expect(
        prefs.trackedApps.map((e) => e.logicalId),
        containsAll(defaultTrackedApps.map((e) => e.logicalId)),
      );
    });

    test('persists custom tracked apps as structured data', () async {
      final repo = SharedPrefsDrawingAppPreferencesRepository();
      const customApp = TrackedApp(
        logicalId: 'custom_example',
        displayName: 'My Paint App',
        iconAsset: null,
        ids: [
          AppIdentifier(
            platform: AppPlatform.macos,
            value: 'com.example.mypaint',
          ),
        ],
      );

      await repo.save(
        const DrawingAppPreferences(trackedApps: [customApp]),
      );

      final reloaded = await repo.load();

      expect(reloaded.trackedApps.length, 1);
      expect(reloaded.trackedApps.first.logicalId, 'custom_example');
      expect(
        reloaded.trackedApps.first.ids.first.value,
        'com.example.mypaint',
      );
    });
  });
}
