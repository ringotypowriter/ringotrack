import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ringotrack/domain/app_database.dart';
import 'package:ringotrack/domain/usage_repository.dart';
import 'package:ringotrack/domain/usage_service.dart';
import 'package:ringotrack/pages/dashboard_page.dart';
import 'package:ringotrack/pages/settings_page.dart';
import 'package:ringotrack/platform/foreground_app_tracker.dart';

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
                final tween = Tween(begin: begin, end: end).chain(
                  CurveTween(curve: Curves.easeInOut),
                );
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
                final tween = Tween(begin: begin, end: end).chain(
                  CurveTween(curve: Curves.easeInOut),
                );
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
        return MaterialApp.router(
          title: 'RingoTrack',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF5F5F7),
            textTheme: ThemeData.light().textTheme.apply(
              fontFamilyFallback: const ['SF Pro Text', 'PingFang SC'],
            ),
          ),
          routerConfig: router,
        );
      },
    );
  }
}

// === Riverpod Providers ===

final _appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  final db = ref.watch(_appDatabaseProvider);
  return SqliteUsageRepository(db);
});

final foregroundAppTrackerProvider = Provider<ForegroundAppTracker>((ref) {
  return createForegroundAppTracker();
});

/// 简单版本：把 macOS 上所有前台应用都视作「绘画软件」以打通链路。
/// 后续会接入真正的绘画软件配置。
bool _defaultIsDrawingApp(String appId) {
  return true;
}

final usageServiceProvider = Provider<UsageService>((ref) {
  final repo = ref.watch(usageRepositoryProvider);
  final tracker = ref.watch(foregroundAppTrackerProvider);

  final service = UsageService(
    isDrawingApp: _defaultIsDrawingApp,
    repository: repo,
    tracker: tracker,
  );

  ref.onDispose(() {
    service.close();
  });

  return service;
});

/// 最近一年的「合并视图」日总时长（所有 App 汇总）
final yearlyDailyTotalsProvider =
    FutureProvider<Map<DateTime, Duration>>((ref) async {
  // 确保 UsageService 已经初始化并开始消费事件
  ref.watch(usageServiceProvider);

  final repo = ref.watch(usageRepositoryProvider);
  final today = DateTime.now();
  final start = DateTime(today.year, 1, 1);
  final end = DateTime(today.year, 12, 31);

  final usageByDate = await repo.loadRange(start, end);

  final totals = <DateTime, Duration>{};
  usageByDate.forEach((day, perApp) {
    totals[day] =
        perApp.values.fold(Duration.zero, (a, b) => a + b);
  });

  return totals;
});

