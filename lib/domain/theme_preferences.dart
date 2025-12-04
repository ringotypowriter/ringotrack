import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringotrack/theme/app_theme.dart';

class ThemePreferencesRepository {
  static const _key = 'ringotrack.themeId';

  Future<AppThemeId> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    return AppThemeIdX.fromName(saved);
  }

  Future<void> save(AppThemeId id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id.name);
  }
}
