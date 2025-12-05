import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/widgets/heatmap_color_scale.dart';

void main() {
  group('HeatmapColorScale legend', () {
    test('returns 5 colors with expected mapping', () {
      const base = Colors.green;
      final colors = HeatmapColorScale.legendColors(base);

      expect(colors.length, 5);

      // 第一个是 0 使用量的色块。
      expect(colors[0], HeatmapColorScale.defaultZeroColor);

      // 第二个是现在 tier1 的色块；
      // 第三个是现在 tier5 的色块；
      // 第五个是现在 tier7 的色块；
      // 第四个为中间值 tier6。
      final tiers = HeatmapColorScale.allTierColors(base);

      expect(colors[1], tiers[0]); // tier1
      expect(colors[2], tiers[4]); // tier5
      expect(colors[3], tiers[5]); // tier6
      expect(colors[4], tiers[6]); // tier7
    });
  });

  group('HeatmapColorScale tiers', () {
    test('exposes 7 tiers constant for downstream algorithms', () {
      expect(HeatmapColorScale.tierCount, 7);
    });
  });
}
