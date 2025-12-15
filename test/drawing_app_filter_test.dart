import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/feature/settings/drawing_app/models/drawing_app_preferences.dart';

void main() {
  group('DrawingApp filter closure', () {
    test('matches only tracked app ids', () {
      final prefs = DrawingAppPreferences(
        trackedApps: [
          const TrackedApp(
            logicalId: 'photoshop',
            displayName: 'Adobe Photoshop',
            iconAsset: null,
            ids: [
              AppIdentifier(
                platform: AppPlatform.macos,
                value: 'com.adobe.photoshop',
              ),
            ],
          ),
        ],
      );

      final filter = buildAppFilter(prefs);

      expect(filter('com.adobe.photoshop'), isTrue);
      expect(filter('com.celsys.clipstudio'), isFalse);
    });

    test('reflects updated preference set', () {
      final prefs = DrawingAppPreferences(
        trackedApps: [
          const TrackedApp(
            logicalId: 'photoshop',
            displayName: 'Adobe Photoshop',
            iconAsset: null,
            ids: [
              AppIdentifier(
                platform: AppPlatform.macos,
                value: 'com.adobe.photoshop',
              ),
            ],
          ),
          const TrackedApp(
            logicalId: 'clipstudio',
            displayName: 'CLIP STUDIO PAINT',
            iconAsset: null,
            ids: [
              AppIdentifier(
                platform: AppPlatform.macos,
                value: 'com.celsys.clipstudio',
              ),
            ],
          ),
        ],
      );

      final filter = buildAppFilter(prefs);

      expect(filter('com.adobe.photoshop'), isTrue);
      expect(filter('com.celsys.clipstudio'), isTrue);
      expect(filter('org.kde.krita'), isFalse);
    });
  });
}
