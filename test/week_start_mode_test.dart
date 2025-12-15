import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/domain/dashboard_preferences.dart';
import 'package:ringotrack/domain/dashboard_preferences_controller.dart';
import 'package:ringotrack/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('startOfWeek respects Sunday as start', () {
    final date = DateTime(2025, 12, 6); // Saturday
    final result = startOfWeek(date, WeekStartMode.sunday);
    expect(result, DateTime(2025, 11, 30));
  });

  test('startOfWeek respects Monday as start', () {
    final date = DateTime(2025, 12, 6); // Saturday
    final result = startOfWeek(date, WeekStartMode.monday);
    expect(result, DateTime(2025, 12, 1));
  });

  test('dashboard preferences repository persists week start mode', () async {
    final repository = DashboardPreferencesRepository();
    await repository.save(
      DashboardPreferences(
        weekStartMode: WeekStartMode.monday,
        enableGlassEffect: false,
      ),
    );

    final loaded = await repository.load();
    expect(loaded.weekStartMode, WeekStartMode.monday);
  });

  test('dashboard preferences repository defaults to monday', () async {
    final repository = DashboardPreferencesRepository();
    final loaded = await repository.load();
    expect(loaded.weekStartMode, WeekStartMode.monday);
  });

  test('dashboard preferences repository persists focus month', () async {
    final repository = DashboardPreferencesRepository();
    final focusMonth = DateTime(2024, 12, 1);
    await repository.save(DashboardPreferences(focusMonth: focusMonth));

    final loaded = await repository.load();
    expect(loaded.focusMonth, focusMonth);
  });

  test(
    'dashboard preferences repository defaults focus month to null',
    () async {
      final repository = DashboardPreferencesRepository();
      final loaded = await repository.load();
      expect(loaded.focusMonth, isNull);
    },
  );

  test(
    'dashboard preferences repository handles invalid focus month string',
    () async {
      SharedPreferences.setMockInitialValues({
        'ringotrack.dashboard.focusMonth': 'invalid-date-string',
      });

      final repository = DashboardPreferencesRepository();
      final loaded = await repository.load();
      expect(loaded.focusMonth, isNull);
    },
  );

  test(
    'dashboard preferences copyWith preserves focus month when explicitly passed',
    () {
      final original = DashboardPreferences(focusMonth: DateTime(2024, 12, 1));
      final copied = original.copyWith(
        selectedYear: 2025,
        focusMonth: original.focusMonth,
      );
      expect(copied.focusMonth, DateTime(2024, 12, 1));
      expect(copied.selectedYear, 2025);
    },
  );

  test('dashboard preferences copyWith updates focus month', () {
    final original = DashboardPreferences(focusMonth: DateTime(2024, 12, 1));
    final newFocusMonth = DateTime(2025, 1, 1);
    final copied = original.copyWith(focusMonth: newFocusMonth);
    expect(copied.focusMonth, newFocusMonth);
  });

  group('DashboardPreferencesController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('setFocusMonth updates focus month', () async {
      final controller = container.read(
        dashboardPreferencesControllerProvider.notifier,
      );
      final focusMonth = DateTime(2024, 12, 1);

      // Wait for initial state to load
      await Future.delayed(Duration.zero);

      await controller.setFocusMonth(focusMonth);

      final prefs = container
          .read(dashboardPreferencesControllerProvider)
          .value;
      expect(prefs?.focusMonth, focusMonth);
    });
  });

  group('heatmapRangeProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('calendar year mode returns full year range', () {
      final controller = container.read(
        dashboardPreferencesControllerProvider.notifier,
      );
      controller.setHeatmapRangeMode(HeatmapRangeMode.calendarYear);

      final range = container.read(heatmapRangeProvider);
      final today = DateTime.now();

      expect(range.start, DateTime(today.year, 1, 1));
      expect(range.end, DateTime(today.year, 12, 31));
    });

    test(
      'calendar year mode with selected year returns that year range',
      () async {
        final controller = container.read(
          dashboardPreferencesControllerProvider.notifier,
        );
        await controller.setHeatmapRangeMode(HeatmapRangeMode.calendarYear);
        await controller.setSelectedYear(2023);

        final range = container.read(heatmapRangeProvider);

        expect(range.start, DateTime(2023, 1, 1));
        expect(range.end, DateTime(2023, 12, 31));
      },
    );

    test(
      'rolling 12 months mode with focus month returns 12 months ending at focus month',
      () async {
        final controller = container.read(
          dashboardPreferencesControllerProvider.notifier,
        );
        await controller.setHeatmapRangeMode(HeatmapRangeMode.rolling12Months);
        final focusMonth = DateTime(2024, 6, 1); // June 2024
        await controller.setFocusMonth(focusMonth);

        final range = container.read(heatmapRangeProvider);

        // Should start 11 months before focus month (July 2023) and end at last day of focus month (June 30, 2024)
        expect(range.start, DateTime(2023, 7, 1));
        expect(range.end, DateTime(2024, 6, 30));
      },
    );

    test(
      'rolling 12 months mode defaults to current month when focus month is null',
      () {
        final controller = container.read(
          dashboardPreferencesControllerProvider.notifier,
        );
        controller.setHeatmapRangeMode(HeatmapRangeMode.rolling12Months);

        final range = container.read(heatmapRangeProvider);
        final today = DateTime.now();
        final currentMonth = DateTime(today.year, today.month, 1);

        // Should start 11 months before current month
        final expectedStart = DateTime(
          currentMonth.year,
          currentMonth.month - 11,
          1,
        );
        final expectedEnd = DateTime(
          currentMonth.year,
          currentMonth.month + 1,
          0,
        ); // Last day of current month

        expect(range.start, expectedStart);
        expect(range.end, expectedEnd);
      },
    );
  });
}
