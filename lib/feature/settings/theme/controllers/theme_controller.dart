import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ringotrack/feature/settings/theme/models/theme_preferences.dart';
import 'package:ringotrack/theme/app_theme.dart';

class ThemeController extends AsyncNotifier<AppTheme> {
  late final ThemePreferencesRepository _repository;

  @override
  Future<AppTheme> build() async {
    _repository = ref.watch(themePreferencesRepositoryProvider);
    final id = await _repository.load();
    return themeFromId(id);
  }

  Future<void> setTheme(AppThemeId id) async {
    final next = themeFromId(id);
    state = AsyncData(next);
    await _repository.save(id);
  }
}

final themePreferencesRepositoryProvider = Provider<ThemePreferencesRepository>(
  (ref) => ThemePreferencesRepository(),
);

final appThemeControllerProvider =
    AsyncNotifierProvider<ThemeController, AppTheme>(ThemeController.new);
