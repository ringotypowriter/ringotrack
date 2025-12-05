import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ringotrack/providers.dart';
import 'package:ringotrack/platform/window_pin_controller.dart';

class ClockPage extends ConsumerStatefulWidget {
  const ClockPage({super.key});

  @override
  ConsumerState<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends ConsumerState<ClockPage> {
  bool _isPinned = false;
  bool _isTogglingPin = false;

  Future<void> _togglePin() async {
    if (_isTogglingPin) {
      return;
    }

    final controller = WindowPinController.instance;
    if (!controller.isSupported) {
      return;
    }

    setState(() {
      _isTogglingPin = true;
    });

    final bool success;
    if (_isPinned) {
      success = await controller.exitPinnedMode();
    } else {
      success = await controller.enterPinnedMode();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isTogglingPin = false;
      if (success) {
        _isPinned = !_isPinned;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final theme = Theme.of(context);
    final pinSupported = WindowPinController.instance.isSupported;

    final timeTextStyle = theme.textTheme.displayLarge?.copyWith(
      fontSize: 160.sp,
      letterSpacing: 10.w,
      color: theme.colorScheme.onPrimary,
      fontFamily: 'JetBrainsMono',
    );

    return Scaffold(
      backgroundColor: HSLColor.fromColor(
        theme.colorScheme.primary,
      ).withSaturation(0.6).withLightness(0.6).toColor(),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: [
                  if (!_isPinned)
                    IconButton(
                      onPressed: () => context.go('/'),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: theme.colorScheme.onPrimary,
                      ),
                      tooltip: '返回仪表盘',
                    ),
                  if (_isPinned) SizedBox(width: 48.w, height: 48.w),
                  const Spacer(),
                  if (pinSupported)
                    IconButton(
                      iconSize: _isPinned ? 12 : 24,
                      padding: EdgeInsets.all(8.w),
                      constraints: BoxConstraints(
                        minWidth: 44.w,
                        minHeight: 44.w,
                      ),
                      onPressed: _isTogglingPin ? null : _togglePin,
                      icon: Icon(
                        _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        color: theme.colorScheme.onPrimary,
                      ),
                      tooltip: _isPinned ? '取消锁定并恢复窗口' : '锁定时钟窗口置顶',
                    ),
                ],
              ),
              if (!_isPinned) SizedBox(height: 24.h),
              Expanded(
                child: _buildTimeContent(context, ref, theme, timeTextStyle),
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
        debugPrint('ClockPage metrics error: $err');
        return _buildTimeRow(theme, timeTextStyle, Duration.zero);
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

    final hoursText = hours.toString().padLeft(2, '0');
    final minutesText = minutes.toString().padLeft(2, '0');
    final secondsText = seconds.toString().padLeft(2, '0');

    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _FlipBlock(value: hoursText, textStyle: timeTextStyle),
            SizedBox(width: 18.w),
            _FlipBlock(value: minutesText, textStyle: timeTextStyle),
            SizedBox(width: 18.w),
            _FlipBlock(value: secondsText, textStyle: timeTextStyle),
          ],
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final baseHsl = HSLColor.fromColor(primary);
    final cardHsl = baseHsl
        .withSaturation((baseHsl.saturation * 1.2).clamp(0.0, 1.0))
        .withLightness((baseHsl.lightness * 0.9).clamp(0.0, 1.0));
    final cardColor = cardHsl.toColor();
    final key = ValueKey<String>(value);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) {
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final progress = animation.value;
            final isUnder = child?.key != key;
            final tiltRadians = (1 - progress) * (math.pi / 2);

            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(isUnder ? tiltRadians : -tiltRadians),
              alignment: Alignment.center,
              child: Opacity(opacity: progress.clamp(0.0, 1.0), child: child),
            );
          },
        );
      },
      child: Container(
        key: key,
        padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 40.w),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28.r),
        ),
        child: Text(value, style: textStyle),
      ),
    );
  }
}
