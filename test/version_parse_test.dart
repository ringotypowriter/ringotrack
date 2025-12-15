import 'package:flutter_test/flutter_test.dart';
import 'package:ringotrack/feature/update/github_release_service.dart';

void main() {
  group('Version.parse', () {
    test('parses GitHub tag without build and defaults to build 0', () {
      final version = Version.parse('v0.1.4');

      expect(version, isNotNull);
      expect(version!.major, 0);
      expect(version.minor, 1);
      expect(version.patch, 4);
      expect(version.build, 0);
    });

    test('parses platform-prefixed tag without build', () {
      final version = Version.parse('windows-v1.2.3');

      expect(version, isNotNull);
      expect(version!.major, 1);
      expect(version.minor, 2);
      expect(version.patch, 3);
      expect(version.build, 0);
    });

    test('keeps provided build number when present', () {
      final version = Version.parse('0.9.0+42');

      expect(version, isNotNull);
      expect(version!.build, 42);
    });
  });
}
