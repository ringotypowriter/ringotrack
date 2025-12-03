import 'package:flutter/material.dart';
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
  }
}
