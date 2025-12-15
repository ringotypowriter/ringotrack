import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ringotrack/feature/dashboard/models/dashboard_preferences.dart';
import 'package:ringotrack/feature/dashboard/providers/dashboard_providers.dart';

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

    // Windows 平台：设置 pending 值，下次启动时生效。
    // UI 状态不变，避免背景立即变透明但玻璃效果还没启用。
    if (Platform.isWindows) {
      await _repository.setGlassEffectPending(enabled);
      // 不更新 state，让 UI 保持当前状态
      return;
    }

    // macOS：直接更新，可以实时切换
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

  Future<void> setSelectedYear(int? year) async {
    final current = state.value ?? const DashboardPreferences();
    final next = current.copyWith(selectedYear: year);
    state = AsyncData(next);
    await _repository.save(next);
  }

  Future<void> setFocusMonth(DateTime? month) async {
    final current = state.value ?? const DashboardPreferences();
    final next = current.copyWith(focusMonth: month);
    state = AsyncData(next);
    await _repository.save(next);
  }
}
