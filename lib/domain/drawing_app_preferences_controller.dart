import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ringotrack/domain/drawing_app_preferences.dart';

class DrawingAppPreferencesController
    extends AsyncNotifier<DrawingAppPreferences> {
  late final DrawingAppPreferencesRepository _repository;

  @override
  Future<DrawingAppPreferences> build() async {
    _repository = ref.read(drawingAppPrefsRepositoryProvider);
    final prefs = await _repository.load();
    return prefs;
  }

  Future<void> addApp(String appId) async {
    final normalized = appId.trim().toLowerCase();
    if (normalized.isEmpty) return;

    final current = state.value ??
        const DrawingAppPreferences(trackedAppIds: defaultTrackedAppIds);
    final updated = DrawingAppPreferences(
      trackedAppIds: <String>{...current.trackedAppIds, normalized},
    );

    state = AsyncData(updated);
    await _repository.save(updated);
  }

  Future<void> removeApp(String appId) async {
    final current = state.value;
    if (current == null) return;

    final normalized = appId.trim().toLowerCase();
    final updatedSet = <String>{...current.trackedAppIds}..remove(normalized);
    final updated = DrawingAppPreferences(trackedAppIds: updatedSet);
    state = AsyncData(updated);
    await _repository.save(updated);
  }

  Future<void> replaceAll(Set<String> appIds) async {
    final cleaned = appIds
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty);
    final updated = DrawingAppPreferences(trackedAppIds: cleaned.toSet());
    state = AsyncData(updated);
    await _repository.save(updated);
  }
}

final drawingAppPrefsRepositoryProvider =
    Provider<DrawingAppPreferencesRepository>((ref) {
  return SharedPrefsDrawingAppPreferencesRepository();
});

final drawingAppPrefsControllerProvider =
    AsyncNotifierProvider<DrawingAppPreferencesController,
        DrawingAppPreferences>(DrawingAppPreferencesController.new);
