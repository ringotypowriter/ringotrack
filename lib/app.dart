import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ringotrack/pages/dashboard_page.dart';
import 'package:ringotrack/pages/clock_page.dart';
import 'package:ringotrack/pages/settings_page.dart';
import 'package:ringotrack/providers.dart';
import 'package:ringotrack/theme/app_theme.dart';

class RingoTrackApp extends ConsumerWidget {
  const RingoTrackApp({super.key});

  static const String dashboardRouteName = 'dashboard';
  static const String settingsRouteName = 'settings';
  static const String clockRouteName = 'clock';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(appThemeProvider);
    final currentTheme = themeAsync.asData?.value ?? ringoGreenTheme;

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
                    final slideTween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: Curves.easeInOut));
                    final fadeTween = Tween(
                      begin: 0.0,
                      end: 1.0,
                    ).chain(CurveTween(curve: Curves.easeIn));
                    // 当本页面被其他页面覆盖时（secondaryAnimation），淡出
                    final secondaryFadeTween = Tween(
                      begin: 1.0,
                      end: 0.0,
                    ).chain(CurveTween(curve: Curves.easeOut));
                    return FadeTransition(
                      opacity: secondaryAnimation.drive(secondaryFadeTween),
                      child: FadeTransition(
                        opacity: animation.drive(fadeTween),
                        child: SlideTransition(
                          position: animation.drive(slideTween),
                          child: child,
                        ),
                      ),
                    );
                  },
            );
          },
        ),
        GoRoute(
          path: '/clock',
          name: clockRouteName,
          pageBuilder: (context, state) {
            return CustomTransitionPage<void>(
              key: state.pageKey,
              child: Title(
                title: '全屏时钟',
                color: Colors.black,
                child: const ClockPage(),
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(0.0, 1.0);
                    const end = Offset.zero;
                    final slideTween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: Curves.easeInOut));
                    final fadeTween = Tween(
                      begin: 0.0,
                      end: 1.0,
                    ).chain(CurveTween(curve: Curves.easeIn));
                    final secondaryFadeTween = Tween(
                      begin: 1.0,
                      end: 0.0,
                    ).chain(CurveTween(curve: Curves.easeOut));
                    return FadeTransition(
                      opacity: secondaryAnimation.drive(secondaryFadeTween),
                      child: FadeTransition(
                        opacity: animation.drive(fadeTween),
                        child: SlideTransition(
                          position: animation.drive(slideTween),
                          child: child,
                        ),
                      ),
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
                    final slideTween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: Curves.easeInOut));
                    final fadeTween = Tween(
                      begin: 0.0,
                      end: 1.0,
                    ).chain(CurveTween(curve: Curves.easeIn));
                    final secondaryFadeTween = Tween(
                      begin: 1.0,
                      end: 0.0,
                    ).chain(CurveTween(curve: Curves.easeOut));
                    return FadeTransition(
                      opacity: secondaryAnimation.drive(secondaryFadeTween),
                      child: FadeTransition(
                        opacity: animation.drive(fadeTween),
                        child: SlideTransition(
                          position: animation.drive(slideTween),
                          child: child,
                        ),
                      ),
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
        final themeData = currentTheme.toThemeData();
        return MaterialApp.router(
          title: 'RingoTrack',
          debugShowCheckedModeBanner: false,
          theme: themeData,
          routerConfig: router,
        );
      },
    );
  }
}
