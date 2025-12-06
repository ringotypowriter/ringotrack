import 'dart:io' show Platform;

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
}

final dashboardPreferencesRepositoryProvider =
    Provider<DashboardPreferencesRepository>((ref) {
      return DashboardPreferencesRepository();
    });

final dashboardPreferencesControllerProvider =
    AsyncNotifierProvider<DashboardPreferencesController, DashboardPreferences>(
      DashboardPreferencesController.new,
    );

/// Windows 平台：获取玻璃效果的显示值（pending 值优先，否则用当前值）
/// 用于 UI 显示，让用户看到他们设置的值
final windowsGlassEffectDisplayProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(dashboardPreferencesRepositoryProvider);
  final pending = await repo.getGlassEffectPending();
  if (pending != null) return pending;
  final prefs = await repo.load();
  return prefs.enableGlassEffect;
});
