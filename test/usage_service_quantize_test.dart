import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/domain/usage_service.dart';

void main() {
  group('quantizeUsageWithRemainder', () {
    test('accumulates sub-second remainders into whole seconds', () {
      final day = DateTime(2025, 1, 1);
      final remainder = <DateTime, Map<String, Duration>>{};

      // 第一次：只有 500ms，不足 1 秒，不应产生任何整秒输出，只记录余数。
      final delta1 = quantizeUsageWithRemainder({
        day: {'Photoshop.exe': const Duration(milliseconds: 500)},
      }, remainder);

      expect(delta1, isEmpty);
      expect(remainder.length, 1);
      final r1 = remainder[DateTime(2025, 1, 1)]!['Photoshop.exe']!;
      expect(r1, const Duration(milliseconds: 500));

      // 第二次：再来 600ms，总计 1100ms，应输出 1s，并保留 100ms 余数。
      final delta2 = quantizeUsageWithRemainder({
        day: {'Photoshop.exe': const Duration(milliseconds: 600)},
      }, remainder);

      expect(delta2.length, 1);
      final d2 = delta2[DateTime(2025, 1, 1)]!['Photoshop.exe']!;
      expect(d2, const Duration(seconds: 1));

      final r2 = remainder[DateTime(2025, 1, 1)]!['Photoshop.exe']!;
      expect(r2, const Duration(milliseconds: 100));

      // 第三次：再来 900ms，加上之前 100ms，刚好 1s，应输出 1s，余数被清空。
      final delta3 = quantizeUsageWithRemainder({
        day: {'Photoshop.exe': const Duration(milliseconds: 900)},
      }, remainder);

      expect(delta3.length, 1);
      final d3 = delta3[DateTime(2025, 1, 1)]!['Photoshop.exe']!;
      expect(d3, const Duration(seconds: 1));

      // 所有余数都应该被清空。
      expect(remainder.isEmpty, isTrue);
    });
  });
}
