import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/pages/dashboard_page.dart';

void main() {
  group('DashboardPage layout', () {
    testWidgets('shows summary cards, tabs and heatmap shell',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 1280,
            height: 720,
            child: _DashboardTestHost(),
          ),
        ),
      );

      // 顶部左上角品牌文字
      expect(find.text('Ringotrack'), findsOneWidget);

      // 四个统计卡片标题
      expect(find.text('今日时长'), findsOneWidget);
      expect(find.text('本周时长'), findsOneWidget);
      expect(find.text('本月时长'), findsOneWidget);
      expect(find.text('连续天数'), findsOneWidget);

      // 中部 Tab
      expect(find.text('总览'), findsOneWidget);
      expect(find.text('按软件'), findsOneWidget);
      expect(find.text('分组'), findsOneWidget);

      // 主热力图容器外壳
      expect(
        find.byKey(const ValueKey('dashboard-heatmap-shell')),
        findsOneWidget,
      );
    });
  });
}

class _DashboardTestHost extends StatelessWidget {
  const _DashboardTestHost();

  @override
  Widget build(BuildContext context) {
    final start = DateTime(2025, 1, 1);
    final end = DateTime(2025, 12, 31);
    final dailyTotals = <DateTime, Duration>{
      DateTime(2025, 1, 1): const Duration(minutes: 10),
    };

    return DashboardPage(
      start: start,
      end: end,
      dailyTotals: dailyTotals,
    );
  }
}
