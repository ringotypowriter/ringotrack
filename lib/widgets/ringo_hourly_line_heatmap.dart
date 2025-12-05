import 'package:flutter/material.dart';

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
  State<RingoHourlyLineHeatmap> createState() =>
      _RingoHourlyLineHeatmapState();
}

class _RingoHourlyLineHeatmapState extends State<RingoHourlyLineHeatmap> {
  int? _hoveredHour;
  Duration _hoveredDuration = Duration.zero;

  late double _avgMinutes;
  late double _maxMinutes;

  @override
  void initState() {
    super.initState();
    _recomputeStats();
  }

  @override
  void didUpdateWidget(covariant RingoHourlyLineHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.hourlyTotals, widget.hourlyTotals)) {
      _recomputeStats();
    }
  }

  void _recomputeStats() {
    final nonZero = widget.hourlyTotals.values
        .where((d) => d.inSeconds > 0)
        .toList(growable: false);

    if (nonZero.isEmpty) {
      _avgMinutes = 0;
      _maxMinutes = 0;
      return;
    }

    final minutes = nonZero.map((d) => d.inSeconds / 60.0).toList();
    final total = minutes.fold<double>(0, (sum, m) => sum + m);
    _avgMinutes = total / minutes.length;
    _maxMinutes = minutes.reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final tickStyle =
        widget.tickStyle ?? Theme.of(context).textTheme.bodySmall;

    return LayoutBuilder(
      builder: (context, constraints) {
        final factor =
            widget.widthFactor.clamp(0.6, 1.0); // 保留一定左右留白
        final totalWidth = constraints.maxWidth * factor;
        final segmentCount = 24;
        final totalSpacing =
            widget.segmentSpacing * (segmentCount - 1);
        final segmentWidth =
            (totalWidth - totalSpacing) / segmentCount;

        final segments = <Widget>[];
        for (var hour = 0; hour < segmentCount; hour++) {
          final duration = widget.hourlyTotals[hour] ?? Duration.zero;
          final color = _colorForDuration(
            duration,
            avgMinutes: _avgMinutes,
            maxMinutes: _maxMinutes,
            baseColor: widget.baseColor,
            emptyColor: widget.emptyColor,
          );

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
              height: widget.barHeight,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.horizontal(
                  left: isFirst ? Radius.circular(widget.cornerRadius) : Radius.zero,
                  right: isLast ? Radius.circular(widget.cornerRadius) : Radius.zero,
                ),
              ),
            ),
          );

          segments.add(segment);
          if (hour != segmentCount - 1) {
            segments.add(SizedBox(width: widget.segmentSpacing));
          }
        }

        return SizedBox(
          height: widget.barHeight + (widget.showTicks ? 22 : 0) + 12,
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
                        const SizedBox(height: 10),
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
      height: 12,
      child: Stack(
        children: [
          for (final t in ticks)
            Align(
              alignment: Alignment(-1 + t / 12, 0),
              child: Text(
                t.toString().padLeft(2, '0'),
                style: style?.copyWith(color: Colors.black54, fontSize: 11),
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
    final left =
        hour * (segmentWidth + widget.segmentSpacing) +
        segmentWidth / 2;

    final label = _formatTooltip(hour, duration);

    final textStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
            ) ??
        const TextStyle(color: Colors.white, fontSize: 12);

    return Positioned(
      left: left,
      top: -32,
      child: Transform.translate(
        offset: const Offset(-32, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label, style: textStyle),
        ),
      ),
    );
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

  Color _colorForDuration(
    Duration duration, {
    required double avgMinutes,
    required double maxMinutes,
    required Color baseColor,
    required Color emptyColor,
  }) {
    if (duration.inSeconds <= 0) {
      return emptyColor;
    }

    final minutes = duration.inSeconds / 60.0;

    double relativeScore = 0;
    if (avgMinutes > 0) {
      final ratio = minutes / avgMinutes;
      if (ratio < 0.5) {
        relativeScore = 0.10;
      } else if (ratio < 1.0) {
        relativeScore = 0.22;
      } else if (ratio < 1.5) {
        relativeScore = 0.34;
      } else if (ratio < 1.75) {
        relativeScore = 0.52;
      } else if (ratio < 2.0) {
        relativeScore = 0.64;
      } else if (ratio < 2.25) {
        relativeScore = 0.76;
      } else if (ratio < 2.5) {
        relativeScore = 0.88;
      } else {
        relativeScore = 1.0;
      }
    }

    double absoluteScore;
    if (minutes < 30) {
      absoluteScore = 0.12;
    } else if (minutes < 120) {
      absoluteScore = 0.26;
    } else if (minutes < 240) {
      absoluteScore = 0.40;
    } else if (minutes < 300) {
      absoluteScore = 0.48;
    } else {
      final overBase = minutes / 300.0;
      absoluteScore = 0.52 + (overBase - 1.0) * 0.20;
      if (absoluteScore > 1.0) {
        absoluteScore = 1.0;
      }
    }

    if (maxMinutes > 0) {
      final normalized = minutes / maxMinutes;
      absoluteScore = absoluteScore * 0.7 + normalized * 0.3;
    }

    var intensity =
        relativeScore > absoluteScore ? relativeScore : absoluteScore;

    if (intensity < 0.20) {
      intensity = 0.20;
    } else if (intensity < 0.40) {
      intensity = 0.40;
    } else if (intensity < 0.60) {
      intensity = 0.60;
    } else if (intensity < 0.80) {
      intensity = 0.80;
    } else {
      intensity = 1.0;
    }

    return baseColor.withValues(alpha: intensity);
  }
}
