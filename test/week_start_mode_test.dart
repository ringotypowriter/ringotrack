import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/domain/dashboard_preferences.dart';
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
}
