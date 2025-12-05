import 'package:flutter/material.dart';

/// 统一的热力图颜色深度与 legend 计算工具。
///
/// 目前同时被月历热力图与日内线性热力图复用，后续若需要调整
/// 分段/算法，只需改这里一处。
class HeatmapColorScale {
  HeatmapColorScale._();

  /// 离散 tier 总数（不含空白）。
  static const int tierCount = 7;

  /// 默认的「0 使用量」色块颜色。
  static const Color defaultZeroColor = Color(0xFFE3E3E3);

  /// 评分分段阈值，用于把连续强度映射到 7 个 tier。
  ///
  /// 注意：这是「分段点」而不是直接用于取色的 alpha。
  /// 颜色值由 [_tierColors] 决定，前 5 档保持原有 5-tier 视觉不变。
  static const List<double> _scoreThresholds = [
    0.20,
    0.35,
    0.50,
    0.65,
    0.80,
    0.90,
    1.0,
  ];

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
    final combinedScore = relativeScore > absoluteScore
        ? relativeScore
        : absoluteScore;
    final tierIndex = _tierForScore(combinedScore);
    final colors = _tierColors(baseColor);

    return colors[tierIndex.clamp(0, colors.length - 1)];
  }

  /// legend 颜色序列（从左到右：0、tier1、tier5、tier6、tier7）。
  static List<Color> legendColors(
    Color baseColor, {
    Color zeroColor = defaultZeroColor,
  }) {
    final tiers = _tierColors(baseColor);

    return <Color>[
      zeroColor, // 0 使用量
      tiers[0], // tier1
      tiers[4], // tier5
      tiers[5], // tier6（中间值）
      tiers[6], // tier7（最深）
    ];
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

  static int _tierForScore(double score) {
    for (var i = 0; i < _scoreThresholds.length; i++) {
      if (score <= _scoreThresholds[i]) {
        return i;
      }
    }
    return _scoreThresholds.length - 1;
  }

  /// 暴露所有 7 档颜色，便于测试与调试。
  static List<Color> allTierColors(Color baseColor) => _tierColors(baseColor);

  /// 7 档颜色，从浅到深。
  ///
  /// 前 5 档使用原来的 alpha：0.20, 0.40, 0.60, 0.80, 1.0，
  /// 后 2 档在保持不透明的前提下降低明度，形成更深的颜色。
  static List<Color> _tierColors(Color baseColor) {
    final opaqueBase = baseColor.withValues(alpha: 1.0);
    final hsl = HSLColor.fromColor(opaqueBase);

    Color darker(double factor) {
      final lightness = (hsl.lightness * factor).clamp(0.0, 1.0);
      return hsl.withLightness(lightness).toColor().withValues(alpha: 1.0);
    }

    return <Color>[
      baseColor.withValues(alpha: 0.20),
      baseColor.withValues(alpha: 0.40),
      baseColor.withValues(alpha: 0.60),
      baseColor.withValues(alpha: 0.80),
      opaqueBase,
      darker(0.85),
      darker(0.70),
    ];
  }
}
