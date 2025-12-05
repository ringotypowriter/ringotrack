import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ringotrack/providers.dart';

class ClockPage extends ConsumerWidget {
  const ClockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final timeTextStyle = theme.textTheme.displayLarge?.copyWith(
      fontSize: 120.sp,
      fontWeight: FontWeight.w500,
      letterSpacing: 6.w,
      color: theme.colorScheme.primary,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontFamilyFallback: const ['SF Mono', 'Menlo', 'Consolas', 'PingFang SC'],
    );

    final secondaryTextStyle = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.6),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: '返回仪表盘',
                ),
              ),
              SizedBox(height: 24.h),
              Expanded(
                child: _buildTimeContent(
                  context,
                  ref,
                  theme,
                  timeTextStyle,
                  secondaryTextStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    TextStyle? timeTextStyle,
    TextStyle? secondaryTextStyle,
  ) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return metricsAsync.when(
      data: (metrics) {
        return _buildTimeRow(theme, timeTextStyle, metrics.today);
      },
      loading: () {
        return _buildTimeRow(theme, timeTextStyle, Duration.zero);
      },
      error: (err, _) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTimeRow(theme, timeTextStyle, Duration.zero),
            SizedBox(height: 16.h),
            if (secondaryTextStyle != null)
              Text(
                '数据加载失败：$err',
                style: secondaryTextStyle.copyWith(
                  color: theme.colorScheme.error.withOpacity(0.8),
                  fontSize: secondaryTextStyle.fontSize?.sp,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        );
      },
    );
  }

  Widget _buildTimeRow(
    ThemeData theme,
    TextStyle? timeTextStyle,
    Duration duration,
  ) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final children = <Widget>[];

    void addSegment(String text) {
      if (children.isNotEmpty) {
        children.add(SizedBox(width: 14.w));
      }
      children.add(_FlipBlock(value: text, textStyle: timeTextStyle));
    }

    if (hours > 0) {
      addSegment('${hours}hr');
    }
    if (minutes > 0) {
      addSegment('${minutes}m');
    }
    if (seconds > 0) {
      addSegment('${seconds}s');
    }
    if (children.isEmpty) {
      addSegment('0s');
    }

    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }
}

class _FlipBlock extends StatelessWidget {
  const _FlipBlock({required this.value, required this.textStyle});

  final String value;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      child: Text(value, key: ValueKey(value), style: textStyle),
    );
  }
}
