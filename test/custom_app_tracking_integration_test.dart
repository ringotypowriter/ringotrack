import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringotrack/feature/settings/drawing_app/models/drawing_app_preferences.dart';
import 'package:ringotrack/feature/settings/drawing_app/controllers/drawing_app_preferences_controller.dart';
import 'package:ringotrack/feature/usage/models/usage_models.dart';

void main() {
  group('Custom App Tracking Integration Tests', () {
    late ProviderContainer container;
    late DrawingAppPreferencesController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      controller = container.read(drawingAppPrefsControllerProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    group('DrawingAppPreferencesController.addApp method', () {
      test('adds custom app with proper structure', () async {
        // Arrange
        const customAppName = 'MyCustomPaintApp';

        // Act
        await controller.addApp(customAppName);

        // Assert
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        expect(prefs, isNotNull);
        expect(prefs!.trackedApps.length, greaterThan(0));

        final customApp = prefs.trackedApps.firstWhere(
          (app) => app.logicalId.startsWith('custom_'),
          orElse: () => throw StateError('Custom app not found'),
        );

        expect(customApp.displayName, customAppName);
        expect(customApp.logicalId, startsWith('custom_'));
        expect(customApp.iconAsset, isNull);
        expect(customApp.ids.length, 1);
        expect(customApp.ids.first.value, customAppName.toLowerCase());
      });

      test('handles empty string input gracefully', () async {
        // Arrange
        const emptyInput = '';

        // Act
        await controller.addApp(emptyInput);

        // Assert
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        expect(prefs, isNotNull);
        // Should not add any custom apps for empty input
        final customApps = prefs!.trackedApps
            .where((app) => app.logicalId.startsWith('custom_'))
            .toList();
        expect(customApps, isEmpty);
      });

      test('handles whitespace-only input', () async {
        // Arrange
        const whitespaceInput = '   ';

        // Act
        await controller.addApp(whitespaceInput);

        // Assert
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        expect(prefs, isNotNull);
        // Should not add any custom apps for whitespace input
        final customApps = prefs!.trackedApps
            .where((app) => app.logicalId.startsWith('custom_'))
            .toList();
        expect(customApps, isEmpty);
      });

      test('prevents duplicate custom app additions', () async {
        // Arrange
        const customAppName = 'MyCustomPaintApp';

        // Act - Add the same app twice
        await controller.addApp(customAppName);
        await controller.addApp(customAppName);

        // Assert
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        expect(prefs, isNotNull);

        final customApps = prefs!.trackedApps
            .where((app) => app.logicalId.startsWith('custom_'))
            .toList();
        expect(customApps.length, 1); // Should only have one instance
      });

      test('adds built-in app from identifier', () async {
        // Arrange
        const photoshopIdentifier = 'photoshop.exe';

        // Act
        await controller.addApp(photoshopIdentifier);

        // Assert
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        expect(prefs, isNotNull);

        final photoshopApp = prefs!.trackedApps.firstWhere(
          (app) => app.logicalId == 'photoshop',
          orElse: () => throw StateError('Photoshop app not found'),
        );

        expect(photoshopApp.displayName, 'Adobe Photoshop');
        expect(photoshopApp.iconAsset, isNotNull);
        expect(photoshopApp.ids.length, greaterThanOrEqualTo(1));
        expect(
          photoshopApp.ids.any(
            (id) => id.value.toLowerCase() == photoshopIdentifier,
          ),
          isTrue,
        );
      });
    });

    group('Custom app appears in tracked apps list', () {
      test('custom app is included in preferences trackedApps', () async {
        // Arrange
        const customAppName = 'MyCustomPaintApp';

        // Act
        await controller.addApp(customAppName);

        // Assert
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        expect(prefs, isNotNull);

        final appNames = prefs!.trackedApps
            .map((app) => app.displayName)
            .toSet();
        expect(appNames, contains(customAppName));
      });

      test('custom app persists after reload', () async {
        // Arrange
        const customAppName = 'MyCustomPaintApp';
        await controller.addApp(customAppName);

        // Act - Simulate reload by creating a new controller instance
        // This tests the persistence layer without creating container conflicts
        final repository = SharedPrefsDrawingAppPreferencesRepository();
        final reloadedPrefs = await repository.load();

        // Assert
        expect(reloadedPrefs, isNotNull);
        final appNames = reloadedPrefs.trackedApps
            .map((app) => app.displayName)
            .toSet();
        expect(appNames, contains(customAppName));
      });
    });

    group('Filter function recognizes custom apps', () {
      test('buildAppFilter includes custom app identifiers', () async {
        // Arrange
        const customAppName = 'MyCustomPaintApp';
        await controller.addApp(customAppName);

        // Act
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        final filter = buildAppFilter(prefs!);

        // Assert
        expect(filter(customAppName), isTrue);
        expect(filter(customAppName.toLowerCase()), isTrue);
        expect(filter('MyCustomPaintApp'), isTrue);
      });

      test('filter works with UsageAggregator for custom apps', () async {
        // Arrange
        const customAppName = 'MyCustomPaintApp';
        await controller.addApp(customAppName);

        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        final filter = buildAppFilter(prefs!);

        final aggregator = UsageAggregator(isDrawingApp: filter);
        final day = DateTime(2025, 1, 1);
        final start = day.add(const Duration(hours: 9, minutes: 10));
        final end = day.add(const Duration(hours: 9, minutes: 40));

        // Act
        aggregator.onForegroundAppChanged(
          ForegroundAppEvent(appId: customAppName, timestamp: start),
        );
        aggregator.onForegroundAppChanged(
          ForegroundAppEvent(appId: 'OtherApp', timestamp: end),
        );

        // Assert
        final usage = aggregator.usageByDate;
        final key = DateTime(2025, 1, 1);

        expect(usage.containsKey(key), isTrue);
        expect(usage[key]!.containsKey(customAppName), isTrue);
        expect(usage[key]![customAppName]!.inMinutes, closeTo(30, 1));
        expect(usage[key]!.containsKey('OtherApp'), isFalse);
      });

      test('filter handles case-insensitive matching', () async {
        // Arrange
        const customAppName = 'MyCustomPaintApp';
        await controller.addApp(customAppName);

        // Act
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        final filter = buildAppFilter(prefs!);

        // Assert
        expect(filter('mycustompaintapp'), isTrue);
        expect(filter('MYCUSTOMPAINTAPP'), isTrue);
        expect(filter('MyCustomPaintApp'), isTrue);
        expect(filter('differentapp'), isFalse);
      });
    });

    group('Custom app removal functionality', () {
      test('removes custom app successfully', () async {
        // Arrange
        const customAppName = 'MyCustomPaintApp';
        await controller.addApp(customAppName);

        // Act
        await controller.removeApp(customAppName);

        // Assert
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        expect(prefs, isNotNull);

        final appNames = prefs!.trackedApps
            .map((app) => app.displayName)
            .toSet();
        expect(appNames, isNot(contains(customAppName)));
      });

      test('removes custom app by logicalId', () async {
        // Arrange
        const customAppName = 'MyCustomPaintApp';
        await controller.addApp(customAppName);

        // Get the logicalId of the added custom app
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        final customApp = prefs!.trackedApps.firstWhere(
          (app) => app.displayName == customAppName,
        );

        // Act
        await controller.removeApp(customApp.logicalId);

        // Assert
        final updatedPrefs = container
            .read(drawingAppPrefsControllerProvider)
            .value;
        expect(updatedPrefs, isNotNull);

        final appNames = updatedPrefs!.trackedApps
            .map((app) => app.displayName)
            .toSet();
        expect(appNames, isNot(contains(customAppName)));
      });

      test('preserves other apps when removing custom app', () async {
        // Arrange
        const customAppName = 'MyCustomPaintApp';
        const photoshopIdentifier = 'photoshop.exe';

        await controller.addApp(customAppName);
        await controller.addApp(photoshopIdentifier);

        // Act
        await controller.removeApp(customAppName);

        // Assert
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        expect(prefs, isNotNull);

        final appNames = prefs!.trackedApps
            .map((app) => app.displayName)
            .toSet();
        expect(appNames, isNot(contains(customAppName)));
        expect(appNames, contains('Adobe Photoshop'));
      });
    });

    group('Edge cases and error handling', () {
      test('handles removal of non-existent app gracefully', () async {
        // Arrange
        const nonExistentApp = 'NonExistentApp';

        // Act & Assert - Should not throw
        await controller.removeApp(nonExistentApp);

        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        expect(prefs, isNotNull);
        expect(prefs!.trackedApps, isNotNull);
      });

      test('handles special characters in app names', () async {
        // Arrange
        const specialCharApp = 'My-Paint_App@2.0!';

        // Act
        await controller.addApp(specialCharApp);

        // Assert
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        expect(prefs, isNotNull);

        final customApp = prefs!.trackedApps.firstWhere(
          (app) => app.logicalId.startsWith('custom_'),
          orElse: () => throw StateError('Custom app not found'),
        );

        expect(customApp.displayName, specialCharApp);
        expect(customApp.ids.first.value, specialCharApp.toLowerCase());
      });

      test('handles very long app names', () async {
        // Arrange
        const longAppName =
            'MySuperLongPaintApplicationNameVersion2024ProfessionalEdition';

        // Act
        await controller.addApp(longAppName);

        // Assert
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        expect(prefs, isNotNull);

        final customApp = prefs!.trackedApps.firstWhere(
          (app) => app.logicalId.startsWith('custom_'),
          orElse: () => throw StateError('Custom app not found'),
        );

        expect(customApp.displayName, longAppName);
        expect(customApp.logicalId, startsWith('custom_'));
      });

      test('maintains data integrity with multiple operations', () async {
        // Arrange & Act - Perform multiple add/remove operations
        await controller.addApp('App1');
        await controller.addApp('App2');
        await controller.removeApp('App1');
        await controller.addApp('App3');
        await controller.addApp('App2'); // Duplicate
        await controller.removeApp('NonExistent');

        // Assert
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        expect(prefs, isNotNull);

        final appNames = prefs!.trackedApps
            .map((app) => app.displayName)
            .toSet();
        expect(appNames, contains('App2'));
        expect(appNames, contains('App3'));
        expect(appNames, isNot(contains('App1')));

        // Verify filter works for remaining apps
        final filter = buildAppFilter(prefs);
        expect(filter('App2'), isTrue);
        expect(filter('App3'), isTrue);
        expect(filter('App1'), isFalse);
      });
    });

    group('Integration with default apps', () {
      test('custom apps coexist with default tracked apps', () async {
        // Arrange
        const customAppName = 'MyCustomPaintApp';

        // Act
        await controller.addApp(customAppName);

        // Assert
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        expect(prefs, isNotNull);
        expect(prefs!.trackedApps.length, greaterThan(1));

        // Should have both custom and default apps
        final hasCustomApp = prefs.trackedApps.any(
          (app) => app.logicalId.startsWith('custom_'),
        );
        final hasDefaultApp = prefs.trackedApps.any(
          (app) => !app.logicalId.startsWith('custom_'),
        );

        expect(hasCustomApp, isTrue);
        expect(hasDefaultApp, isTrue);
      });

      test('filter recognizes both custom and default apps', () async {
        // Arrange
        const customAppName = 'MyCustomPaintApp';
        const photoshopIdentifier = 'photoshop.exe';

        await controller.addApp(customAppName);
        await controller.addApp(photoshopIdentifier);

        // Act
        final prefs = container.read(drawingAppPrefsControllerProvider).value;
        final filter = buildAppFilter(prefs!);

        // Assert
        expect(filter(customAppName), isTrue);
        expect(filter('photoshop.exe'), isTrue);
        expect(
          filter('com.adobe.photoshop'),
          isTrue,
        ); // Should also match macOS identifier
        expect(filter('untracked_app'), isFalse);
      });
    });
  });
}
