import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ringotrack/widgets/heatmap_color_scale.dart';

const int _secondsPerHour = 3600;

/// 单日 24 小时线性热力图。
///
/// 颜色分段与日历热力图保持一致，便于复用同一 legend。
class RingoHourlyLineHeatmap extends StatefulWidget {
  const RingoHourlyLineHeatmap({
    super.key,
    required this.hourlyTotals,
    this.baseColor = Colors.green,
    this.emptyColor = const Color(0xFFE3E3E3),
    this.barHeight = 12,
    this.segmentSpacing = 0,
    this.cornerRadius = 3,
    this.showTicks = true,
    this.tickStyle,
    this.widthFactor = 0.9,
  });

  /// 0-23 -> 总时长
  final Map<int, Duration> hourlyTotals;
  final Color baseColor;
  final Color emptyColor;
  final double barHeight;
  final double segmentSpacing;
  final double cornerRadius;
  final bool showTicks;
  final TextStyle? tickStyle;

  /// 相对可用宽度的占比，避免铺满让视觉更内敛。
  final double widthFactor;

  @override
  State<RingoHourlyLineHeatmap> createState() => _RingoHourlyLineHeatmapState();
}

class _RingoHourlyLineHeatmapState extends State<RingoHourlyLineHeatmap> {
  int? _hoveredHour;
  Duration _hoveredDuration = Duration.zero;

  @override
  Widget build(BuildContext context) {
    final tickStyle = widget.tickStyle ?? Theme.of(context).textTheme.bodySmall;

    return LayoutBuilder(
      builder: (context, constraints) {
        final factor = widget.widthFactor.clamp(0.6, 1.0); // 保留一定左右留白
        final totalWidth = constraints.maxWidth * factor;
        final segmentCount = 24;
        final spacing = widget.segmentSpacing.w;
        final totalSpacing = spacing * (segmentCount - 1);
        final segmentWidth = (totalWidth - totalSpacing) / segmentCount;
        final barHeight = widget.barHeight.h;
        final radius = widget.cornerRadius.r;
        final tierColors = HeatmapColorScale.allTierColors(widget.baseColor);

        final segments = <Widget>[];
        for (var hour = 0; hour < segmentCount; hour++) {
          final duration = widget.hourlyTotals[hour] ?? Duration.zero;
          final color = _colorForHourlySegment(duration, tierColors);

          final isFirst = hour == 0;
          final isLast = hour == segmentCount - 1;

          final segment = MouseRegion(
            onEnter: (_) => setState(() {
              _hoveredHour = hour;
              _hoveredDuration = duration;
            }),
            onExit: (_) => setState(() {
              if (_hoveredHour == hour) {
                _hoveredHour = null;
                _hoveredDuration = Duration.zero;
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: segmentWidth,
              height: barHeight,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.horizontal(
                  left: isFirst ? Radius.circular(radius) : Radius.zero,
                  right: isLast ? Radius.circular(radius) : Radius.zero,
                ),
              ),
            ),
          );

          segments.add(segment);
          if (hour != segmentCount - 1) {
            segments.add(SizedBox(width: spacing));
          }
        }

        return SizedBox(
          height: barHeight + (widget.showTicks ? 22.h : 0) + 12.h,
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: totalWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: segments,
                      ),
                      if (widget.showTicks) ...[
                        SizedBox(height: 10.h),
                        _buildTicks(tickStyle),
                      ],
                    ],
                  ),
                  if (_hoveredHour != null)
                    _buildTooltip(
                      hour: _hoveredHour!,
                      duration: _hoveredDuration,
                      segmentWidth: segmentWidth,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTicks(TextStyle? style) {
    const ticks = [0, 6, 12, 18, 24];
    return SizedBox(
      height: 12.h,
      child: Stack(
        children: [
          for (final t in ticks)
            Align(
              alignment: Alignment(
                t == 24 ? (1 - 1 / 48) : (-1 + (t + 0.5) / 12).clamp(-1.0, 1.0),
                0,
              ),
              child: Text(
                t.toString().padLeft(2, '0'),
                style: style?.copyWith(color: Colors.black54, fontSize: 11.sp),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTooltip({
    required int hour,
    required Duration duration,
    required double segmentWidth,
  }) {
    final spacing = widget.segmentSpacing.w;
    final left = hour * (segmentWidth + spacing) + segmentWidth / 2;

    final label = _formatTooltip(hour, duration);

    final textStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white) ??
        const TextStyle(color: Colors.white, fontSize: 12);

    return Positioned(
      left: left,
      top: -32.r,
      child: Transform.translate(
        offset: Offset(-32.w, 0),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Text(label, style: textStyle),
        ),
      ),
    );
  }

  /// 以小时内绘画时间占比决定 tier：任意非零都算 tier1，满 1 小时则为 tier7。
  Color _colorForHourlySegment(Duration duration, List<Color> tierColors) {
    if (duration.inSeconds <= 0) {
      return widget.emptyColor;
    }

    final normalized = (duration.inSeconds / _secondsPerHour).clamp(0.0, 1.0);
    final tierCount = tierColors.length;
    final tierIndex = normalized >= 1.0
        ? tierCount - 1
        : (normalized * tierCount).ceil() - 1;

    return tierColors[tierIndex.clamp(0, tierCount - 1)];
  }

  String _formatTooltip(int hour, Duration duration) {
    final hourLabel = hour.toString().padLeft(2, '0');
    return '$hourLabel:00 · ${_formatDuration(duration)}';
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0) return '0s';

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h '
          '${minutes.toString().padLeft(2, '0')}m '
          '${seconds.toString().padLeft(2, '0')}s';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }
}
