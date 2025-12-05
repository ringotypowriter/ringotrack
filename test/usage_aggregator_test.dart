import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/domain/usage_models.dart';

void main() {
  group('UsageAggregator', () {
    test('counts single drawing app session in one day (TC-F-01)', () {
      final aggregator = UsageAggregator(
        isDrawingApp: (id) => id == 'Photoshop.exe',
      );

      final day = DateTime(
        2025,
        1,
        1,
      ); // treat as local midnight base for the day
      final start = day.add(const Duration(hours: 9, minutes: 10));
      final end = day.add(const Duration(hours: 9, minutes: 40));

      aggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: 'Photoshop.exe', timestamp: start),
      );

      aggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: 'OtherApp', timestamp: end),
      );

      final usage = aggregator.usageByDate;
      final key = DateTime(2025, 1, 1);

      expect(usage.containsKey(key), isTrue);
      final photoshopDuration = usage[key]!['Photoshop.exe']!;

      expect(photoshopDuration.inMinutes, closeTo(30, 1));
    });

    test('sums multiple sessions of same app (TC-F-02)', () {
      final aggregator = UsageAggregator(
        isDrawingApp: (id) => id == 'CLIPStudioPaint.exe',
      );

      final day = DateTime(2025, 1, 1);

      final firstStart = day.add(const Duration(hours: 10));
      final firstEnd = day.add(const Duration(hours: 10, minutes: 20));
      final secondStart = day.add(const Duration(hours: 10, minutes: 30));
      final secondEnd = day.add(const Duration(hours: 11, minutes: 10));

      aggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: 'CLIPStudioPaint.exe', timestamp: firstStart),
      );
      aggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: 'Browser', timestamp: firstEnd),
      );

      aggregator.onForegroundAppChanged(
        ForegroundAppEvent(
          appId: 'CLIPStudioPaint.exe',
          timestamp: secondStart,
        ),
      );
      aggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: 'Browser', timestamp: secondEnd),
      );

      final usage = aggregator.usageByDate;
      final key = DateTime(2025, 1, 1);

      final duration = usage[key]!['CLIPStudioPaint.exe']!;
      expect(duration.inMinutes, closeTo(60, 1));
    });

    test('splits usage across days at midnight (TC-F-03)', () {
      final aggregator = UsageAggregator(
        isDrawingApp: (id) => id == 'Krita.exe',
      );

      final day1 = DateTime(2025, 1, 1);
      final start = day1.add(const Duration(hours: 23, minutes: 50));
      final day2 = DateTime(2025, 1, 2);
      final end = day2.add(const Duration(minutes: 10));

      aggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: 'Krita.exe', timestamp: start),
      );
      aggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: 'Browser', timestamp: end),
      );

      final usage = aggregator.usageByDate;
      final key1 = DateTime(2025, 1, 1);
      final key2 = DateTime(2025, 1, 2);

      final duration1 = usage[key1]!['Krita.exe']!;
      final duration2 = usage[key2]!['Krita.exe']!;

      expect(duration1.inMinutes, closeTo(10, 1));
      expect(duration2.inMinutes, closeTo(10, 1));
    });

    test('ignores non-drawing apps completely (TC-F-04)', () {
      final aggregator = UsageAggregator(
        isDrawingApp: (id) => id == 'Photoshop.exe',
      );

      final day = DateTime(2025, 1, 1);
      final start = day.add(const Duration(hours: 10));
      final end = day.add(const Duration(hours: 12));

      aggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: 'Browser', timestamp: start),
      );
      aggregator.onForegroundAppChanged(
        ForegroundAppEvent(appId: 'Player', timestamp: end),
      );

      expect(aggregator.usageByDate.isEmpty, isTrue);
    });

    test(
      'adding drawing app later only counts time after tracking starts (TC-F-05 simplified)',
      () {
        var drawingApps = <String>{};

        final aggregator = UsageAggregator(
          isDrawingApp: (id) => drawingApps.contains(id),
        );

        final day = DateTime(2025, 1, 1);
        final startTracking = day.add(const Duration(hours: 10, minutes: 30));
        final end = day.add(const Duration(hours: 11));

        drawingApps.add('PureRef');

        aggregator.onForegroundAppChanged(
          ForegroundAppEvent(appId: 'PureRef', timestamp: startTracking),
        );
        aggregator.onForegroundAppChanged(
          ForegroundAppEvent(appId: 'Browser', timestamp: end),
        );

        final usage = aggregator.usageByDate;
        final key = DateTime(2025, 1, 1);

        final duration = usage[key]!['PureRef']!;
        expect(duration.inMinutes, closeTo(30, 1));
      },
    );
  });
}
