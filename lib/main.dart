import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ringotrack/pages/dashboard_page.dart';

void main() {
  runApp(const RingoTrackApp());
}

class RingoTrackApp extends StatelessWidget {
  const RingoTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final end = DateTime(today.year, 12, 31);
    final start = DateTime(today.year, 1, 1);

    final sampleDailyTotals = <DateTime, Duration>{
      for (var i = 0; i < 365; i++)
        start.add(Duration(days: i)):
            Duration(minutes: (i * 13) % 240),
    };

    // 以 1440x900 的桌面设计稿作为基准做响应式适配
    return ScreenUtilInit(
      designSize: const Size(1440, 900),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'RingoTrack',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF5F5F7),
            textTheme: ThemeData.light().textTheme.apply(
              fontFamilyFallback: const ['SF Pro Text', 'PingFang SC'],
            ),
          ),
          home: Title(
            title: '仪表盘',
            color: Colors.black,
            child: DashboardPage(
              start: start,
              end: end,
              dailyTotals: sampleDailyTotals,
            ),
          ),
        );
      },
    );
  }
}
