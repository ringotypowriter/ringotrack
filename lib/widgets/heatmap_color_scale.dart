import 'package:flutter/material.dart';

/// 统一的热力图颜色深度与 legend 计算工具。
///
/// 目前同时被月历热力图与日内线性热力图复用，后续若需要调整
/// 分段/算法，只需改这里一处。
class HeatmapColorScale {
  HeatmapColorScale._();

  /// 离散分桶，用于颜色强度和 legend。
  static const List<double> bucketStops = [0.20, 0.40, 0.60, 0.80, 1.0];

  /// 根据时长与统计量计算对应颜色。
  static Color colorForDuration(
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

    final relativeScore = _relativeScore(minutes, avgMinutes);
    final absoluteScore = _absoluteScore(minutes, maxMinutes);
    final intensity = _bucketize(
      relativeScore > absoluteScore ? relativeScore : absoluteScore,
    );

    return baseColor.withValues(alpha: intensity);
  }

  /// legend 颜色序列（从浅到深）。
  static List<Color> legendColors(Color baseColor) {
    return bucketStops
        .map((stop) => baseColor.withValues(alpha: stop))
        .toList(growable: false);
  }

  static double _relativeScore(double minutes, double avgMinutes) {
    if (avgMinutes <= 0) return 0;

    final ratio = minutes / avgMinutes;
    if (ratio < 0.5) return 0.10;
    if (ratio < 1.0) return 0.22;
    if (ratio < 1.5) return 0.34;
    if (ratio < 1.75) return 0.52;
    if (ratio < 2.0) return 0.64;
    if (ratio < 2.25) return 0.76;
    if (ratio < 2.5) return 0.88;
    return 1.0;
  }

  static double _absoluteScore(double minutes, double maxMinutes) {
    double score;
    if (minutes < 30) {
      score = 0.12;
    } else if (minutes < 120) {
      score = 0.26;
    } else if (minutes < 240) {
      score = 0.40;
    } else if (minutes < 300) {
      score = 0.48;
    } else {
      final overBase = minutes / 300.0;
      score = 0.52 + (overBase - 1.0) * 0.20;
      if (score > 1.0) {
        score = 1.0;
      }
    }

    if (maxMinutes > 0) {
      final normalized = minutes / maxMinutes;
      score = score * 0.7 + normalized * 0.3;
    }

    return score;
  }

  static double _bucketize(double intensity) {
    for (final bucket in bucketStops) {
      if (intensity <= bucket) {
        return bucket;
      }
    }
    return bucketStops.last;
  }
}
