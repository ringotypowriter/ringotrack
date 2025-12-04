import 'package:flutter/material.dart';

/// 可选主题的唯一标识
enum AppThemeId { ringoGreen, exusiaiCoral }

/// 主题描述结构，集中管理颜色与 ThemeData 构建。
class AppTheme {
  const AppTheme({
    required this.id,
    required this.name,
    required this.seedColor,
    required this.primary,
    required this.surface,
    required this.scaffoldBackground,
  });

  final AppThemeId id;
  final String name;
  final Color seedColor;
  final Color primary;
  final Color surface;
  final Color scaffoldBackground;

  ThemeData toThemeData() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: baseScheme.copyWith(
        primary: primary,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: ThemeData.light().textTheme.apply(
        fontFamilyFallback: const ['SF Pro Text', 'PingFang SC'],
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE1E7DF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE1E7DF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: Color(0xFFB9D6C5)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      dividerColor: const Color(0xFFE1E7DF),
    );
  }
}

const AppTheme ringoGreenTheme = AppTheme(
  id: AppThemeId.ringoGreen,
  name: '青绿',
  seedColor: Color(0xFF4AC26B),
  primary: Color(0xFF4AC26B),
  surface: Colors.white,
  scaffoldBackground: Color(0xFFF6F8F5),
);

const AppTheme exusiaiCoralTheme = AppTheme(
  id: AppThemeId.exusiaiCoral,
  name: '珊瑚红',
  seedColor: Color(0xFFFF6B6B),
  primary: Color(0xFFFF5E5E),
  surface: Colors.white,
  scaffoldBackground: Color(0xFFFFF7F5),
);

const List<AppTheme> availableThemes = [
  ringoGreenTheme,
  exusiaiCoralTheme,
];

AppTheme themeFromId(AppThemeId id) {
  return availableThemes.firstWhere(
    (t) => t.id == id,
    orElse: () => ringoGreenTheme,
  );
}

extension AppThemeIdX on AppThemeId {
  static AppThemeId fromName(String? value) {
    if (value == null) return AppThemeId.ringoGreen;
    return AppThemeId.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppThemeId.ringoGreen,
    );
  }
}
