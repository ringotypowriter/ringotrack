import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringotrack/domain/drawing_app_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DrawingAppPreferencesRepository', () {
    test('returns default tracked app ids when empty store', () async {
      final repo = SharedPrefsDrawingAppPreferencesRepository();

      final prefs = await repo.load();

      // 至少要包含常见绘画软件的 bundleId
      expect(
        prefs.trackedAppIds,
        containsAll(defaultTrackedAppIds),
      );
    });

    test('persists custom tracked app ids', () async {
      final repo = SharedPrefsDrawingAppPreferencesRepository();
      final custom = {'Com.Example.A', 'com.example.B'};

      await repo.save(DrawingAppPreferences(trackedAppIds: custom));

      final reloaded = await repo.load();

      expect(reloaded.trackedAppIds, equals({'com.example.a', 'com.example.b'}));
    });
  });
}
