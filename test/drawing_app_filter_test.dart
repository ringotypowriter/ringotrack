import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/domain/drawing_app_preferences.dart';

void main() {
  group('DrawingApp filter closure', () {
    test('matches only tracked app ids', () {
      final prefs = DrawingAppPreferences(trackedAppIds: {
        'com.adobe.photoshop',
      });

      final filter = buildAppFilter(prefs);

      expect(filter('com.adobe.photoshop'), isTrue);
      expect(filter('com.celsys.clipstudio'), isFalse);
    });

    test('reflects updated preference set', () {
      final prefs = DrawingAppPreferences(trackedAppIds: {
        'com.adobe.photoshop',
        'com.celsys.clipstudio',
      });

      final filter = buildAppFilter(prefs);

      expect(filter('com.adobe.photoshop'), isTrue);
      expect(filter('com.celsys.clipstudio'), isTrue);
      expect(filter('org.kde.krita'), isFalse);
    });
  });
}
