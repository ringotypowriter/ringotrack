import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ringotrack/feature/settings/drawing_app/models/drawing_app_preferences.dart';

import 'package:flutter/foundation.dart';

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
    final current =
        state.value ??
        const DrawingAppPreferences(trackedApps: defaultTrackedApps);

    // 1. 先看是否命中内置列表的任意 identifier
    TrackedApp? matchedDefault;
    for (final app in defaultTrackedApps) {
      for (final id in app.ids) {
        if (id.value.toLowerCase() == normalized) {
          matchedDefault = app;
          break;
        }
      }
      if (matchedDefault != null) break;
    }

    final List<TrackedApp> updatedApps = [...current.trackedApps];

    if (matchedDefault != null) {
      final index = updatedApps.indexWhere(
        (app) => app.logicalId == matchedDefault!.logicalId,
      );
      if (index == -1) {
        updatedApps.add(matchedDefault);
      } else {
        final existing = updatedApps[index];
        updatedApps[index] = existing.addIdentifier(
          matchedDefault.ids.firstWhere(
            (id) => id.value.toLowerCase() == normalized,
            orElse: () =>
                AppIdentifier(platform: AppPlatform.other, value: normalized),
          ),
        );
      }
    } else {
      // 2. 自定义应用：新建一个结构化记录，DisplayName 先用原始输入
      final logicalId = 'custom_${normalized.hashCode}';
      final displayName = appId.trim();

      if (updatedApps.any((app) => app.logicalId == logicalId)) {
        if (kDebugMode) {
          // 已存在同名自定义应用时不重复添加
          debugPrint(
            '[DrawingAppPreferencesController] custom app already exists: '
            '$logicalId',
          );
        }
      } else {
        updatedApps.add(
          TrackedApp(
            logicalId: logicalId,
            displayName: displayName,
            iconAsset: null,
            ids: [
              AppIdentifier(
                platform: defaultTargetPlatform == TargetPlatform.macOS
                    ? AppPlatform.macos
                    : defaultTargetPlatform == TargetPlatform.windows
                    ? AppPlatform.windows
                    : AppPlatform.other,
                value: normalized,
              ),
            ],
          ),
        );
      }
    }

    final updated = DrawingAppPreferences(trackedApps: updatedApps);
    state = AsyncData(updated);
    await _repository.save(updated);
  }

  Future<void> removeApp(String appId) async {
    final current = state.value;
    if (current == null) return;

    final normalized = appId.trim().toLowerCase();
    final updatedApps = current.trackedApps
        .where(
          (app) =>
              !app.ids.any((id) => id.value.toLowerCase() == normalized) &&
              app.logicalId != normalized,
        )
        .toList();
    final updated = DrawingAppPreferences(trackedApps: updatedApps);
    state = AsyncData(updated);
    await _repository.save(updated);
  }

  Future<void> replaceAll(Set<String> appIds) async {
    final cleaned = appIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    for (final raw in cleaned) {
      await addApp(raw);
    }

    // addApp 已经负责持久化和更新 state，这里直接以当前 state 为准。
    final current =
        state.value ??
        const DrawingAppPreferences(trackedApps: defaultTrackedApps);
    final updated = DrawingAppPreferences(trackedApps: current.trackedApps);
    state = AsyncData(updated);
    await _repository.save(updated);
  }
}

final drawingAppPrefsRepositoryProvider =
    Provider<DrawingAppPreferencesRepository>((ref) {
      return SharedPrefsDrawingAppPreferencesRepository();
    });

final drawingAppPrefsControllerProvider =
    AsyncNotifierProvider<
      DrawingAppPreferencesController,
      DrawingAppPreferences
    >(DrawingAppPreferencesController.new);
