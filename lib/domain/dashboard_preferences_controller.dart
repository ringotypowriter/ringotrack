import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ringotrack/domain/dashboard_preferences.dart';

class DashboardPreferencesController
    extends AsyncNotifier<DashboardPreferences> {
  late final DashboardPreferencesRepository _repository;

  @override
  Future<DashboardPreferences> build() async {
    _repository = ref.read(dashboardPreferencesRepositoryProvider);
    return _repository.load();
  }

  Future<void> setHeatmapRangeMode(HeatmapRangeMode mode) async {
    final current = state.value ?? const DashboardPreferences();
    final next = current.copyWith(heatmapRangeMode: mode);
    state = AsyncData(next);
    await _repository.save(next);
  }

  Future<void> setEnableGlassEffect(bool enabled) async {
    final current = state.value ?? const DashboardPreferences();
    final next = current.copyWith(enableGlassEffect: enabled);
    state = AsyncData(next);
    await _repository.save(next);
  }

  Future<void> setWeekStartMode(WeekStartMode mode) async {
    final current = state.value ?? const DashboardPreferences();
    final next = current.copyWith(weekStartMode: mode);
    state = AsyncData(next);
    await _repository.save(next);
  }
}

final dashboardPreferencesRepositoryProvider =
    Provider<DashboardPreferencesRepository>((ref) {
      return DashboardPreferencesRepository();
    });

final dashboardPreferencesControllerProvider =
    AsyncNotifierProvider<DashboardPreferencesController, DashboardPreferences>(
      DashboardPreferencesController.new,
    );
