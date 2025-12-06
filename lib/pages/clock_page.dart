import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ringotrack/providers.dart';
import 'package:ringotrack/platform/window_pin_controller.dart';
import 'package:ringotrack/platform/glass_tint_controller.dart';

class ClockPage extends ConsumerStatefulWidget {
  const ClockPage({super.key});

  @override
  ConsumerState<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends ConsumerState<ClockPage> {
  bool _isMiniMode = false;
  bool _isTogglingMiniMode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateGlassTint();
  }

  @override
  void dispose() {
    // 离开页面时恢复默认白色 tint（macOS/Windows 都支持更新 tint 颜色）
    GlassTintController.instance.resetTintColor();
    super.dispose();
  }

  /// 根据当前主题更新毛玻璃 tint 颜色
  void _updateGlassTint() {
    final useGlass = ref.read(useGlassEffectProvider);
    if (!useGlass) return;

    final theme = Theme.of(context);
    final clockBgColor = HSLColor.fromColor(
      theme.colorScheme.primary,
    ).withSaturation(0.6).withLightness(0.6).toColor();

    GlassTintController.instance.setTintColor(clockBgColor);
  }

  Future<void> _toggleMiniMode() async {
    if (_isTogglingMiniMode) {
      return;
    }

    final controller = WindowPinController.instance;
    if (!controller.isSupported) {
      return;
    }

    setState(() {
      _isTogglingMiniMode = true;
    });

    final bool success;
    if (_isMiniMode) {
      success = await controller.exitPinnedMode();
    } else {
      success = await controller.enterPinnedMode();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isTogglingMiniMode = false;
      if (success) {
        _isMiniMode = !_isMiniMode;
      }
    });
  }

  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final theme = Theme.of(context);
    final pinSupported = WindowPinController.instance.isSupported;
    final useGlass = ref.watch(useGlassEffectProvider);

    // 监听毛玻璃设置变化（仅 macOS，Windows 不支持实时开/关）
    if (Platform.isMacOS) {
      ref.listen(useGlassEffectProvider, (previous, next) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (next) {
              // 开启毛玻璃：设置彩色 tint
              _updateGlassTint();
            } else {
              // 关闭毛玻璃：恢复默认白色 tint
              GlassTintController.instance.resetTintColor();
            }
          });
        }
      });
    }

    // 监听主题变化，更新 tint（仅在毛玻璃模式下，macOS/Windows 都支持）
    ref.listen(appThemeProvider, (previous, next) {
      if (useGlass && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateGlassTint();
        });
      }
    });

    final timeTextStyle = theme.textTheme.displayLarge?.copyWith(
      fontSize: 160.sp,
      letterSpacing: 10.w,
      color: theme.colorScheme.onPrimary,
      fontFamily: 'JetBrainsMono',
    );

    final clockBgColor = HSLColor.fromColor(
      theme.colorScheme.primary,
    ).withSaturation(0.6).withLightness(0.6).toColor();

    return Scaffold(
      backgroundColor: useGlass ? Colors.transparent : clockBgColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: [
                  if (!_isMiniMode)
                    IconButton(
                      onPressed: () => _handleBack(context),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: theme.colorScheme.onPrimary,
                      ),
                      tooltip: '返回仪表盘',
                    ),
                  if (_isMiniMode) SizedBox(width: 48.w, height: 48.w),
                  const Spacer(),
                  if (pinSupported)
                    IconButton(
                      iconSize: _isMiniMode ? 16 : 24,
                      padding: EdgeInsets.all(8.w),
                      constraints: BoxConstraints(
                        minWidth: 44.w,
                        minHeight: 44.w,
                      ),
                      onPressed: _isTogglingMiniMode ? null : _toggleMiniMode,
                      icon: Icon(
                        _isMiniMode
                            ? Icons.crop_square
                            : Icons.crop_square_outlined,
                        color: theme.colorScheme.onPrimary,
                      ),
                      tooltip: _isMiniMode ? '退出迷你模式' : '进入迷你模式',
                    ),
                ],
              ),
              if (!_isMiniMode) SizedBox(height: 24.h),
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
