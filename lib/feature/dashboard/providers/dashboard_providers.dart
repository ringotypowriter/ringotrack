import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ringotrack/feature/dashboard/models/dashboard_preferences.dart';
import 'package:ringotrack/feature/dashboard/controllers/dashboard_preferences_controller.dart';

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
