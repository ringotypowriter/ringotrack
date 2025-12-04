import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ringotrack/pages/dashboard_page.dart';
import 'package:ringotrack/pages/settings_page.dart';

class RingoTrackApp extends StatelessWidget {
  const RingoTrackApp({super.key});

  static const String dashboardRouteName = 'dashboard';
  static const String settingsRouteName = 'settings';

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: dashboardRouteName,
          pageBuilder: (context, state) {
            return CustomTransitionPage<void>(
              key: state.pageKey,
              child: Title(
                title: '仪表盘',
                color: Colors.black,
                child: const DashboardPage(),
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(-1.0, 0.0);
                    const end = Offset.zero;
                    final tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: Curves.easeInOut));
                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
            );
          },
        ),
        GoRoute(
          path: '/settings',
          name: settingsRouteName,
          pageBuilder: (context, state) {
            return CustomTransitionPage<void>(
              key: state.pageKey,
              child: Title(
                title: '设置',
                color: Colors.black,
                child: const SettingsPage(),
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    final tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: Curves.easeInOut));
                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
            );
          },
        ),
      ],
    );

    return ScreenUtilInit(
      designSize: const Size(1440, 900),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        const seedGreen = Color(0xFF2CB36B);
        return MaterialApp.router(
          title: 'RingoTrack',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: seedGreen,
              brightness: Brightness.light,
              background: const Color(0xFFF6F8F5),
              surface: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFFF6F8F5),
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
                borderSide: const BorderSide(color: seedGreen, width: 1.4),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: seedGreen,
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
                backgroundColor: seedGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: seedGreen,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: seedGreen,
                side: const BorderSide(color: Color(0xFFB9D6C5)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            dividerColor: const Color(0xFFE1E7DF),
          ),
          routerConfig: router,
        );
      },
    );
  }
}
