import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a parsed version with semantic versioning components
class Version {
  const Version({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
  });

  final int major;
  final int minor;
  final int patch;
  final int build;

  /// Parse version string in format "{major}.{minor}.{patch}+{build}" or "v{major}.{minor}.{patch}+{build}"
  /// Also handles platform prefixes like "windows-v{major}.{minor}.{patch}+{build}"
  /// Examples:
  ///   "0.1.3+20" -> Version(major: 0, minor: 1, patch: 3, build: 20)  // App version
  ///   "v0.1.3+23" -> Version(major: 0, minor: 1, patch: 3, build: 23)  // GitHub tag
  ///   "windows-v0.1.3+23" -> Version(major: 0, minor: 1, patch: 3, build: 23)  // Platform tag
  ///   "v0.1.3" -> Version(major: 0, minor: 1, patch: 3, build: 0)  // Default build when missing
  static Version? parse(String versionString) {
    debugPrint('[Version.parse] Input: $versionString');

    String versionWithoutV;

    // Find the 'v' that starts the version number
    final vIndex = versionString.indexOf('v');
    if (vIndex != -1) {
      // Has 'v' prefix - extract from 'v' onwards and remove 'v'
      final cleanVersion = versionString.substring(vIndex);
      debugPrint('[Version.parse] Cleaned version with v: $cleanVersion');
      versionWithoutV = cleanVersion.substring(1);
    } else {
      // No 'v' prefix - use as is (for app version like "0.1.3+20")
      debugPrint('[Version.parse] No v prefix found, using as-is');
      versionWithoutV = versionString;
    }

    // Split by '+' to separate version and build number
    final parts = versionWithoutV.split('+');
    if (parts.length > 2) {
      debugPrint('[Version.parse] Invalid format: too many "+" separators');
      return null;
    }

    final versionPart = parts[0];
    final buildPart = parts.length == 2 ? parts[1] : '0';
    if (parts.length == 1) {
      debugPrint('[Version.parse] No build number found, defaulting to 0');
    }
    debugPrint(
      '[Version.parse] Version part: $versionPart, Build part: $buildPart',
    );

    // Parse version numbers
    final versionNumbers = versionPart.split('.');
    if (versionNumbers.length != 3) {
      debugPrint(
        '[Version.parse] Invalid version format: expected 3 parts separated by "."',
      );
      return null;
    }

    try {
      final major = int.parse(versionNumbers[0]);
      final minor = int.parse(versionNumbers[1]);
      final patch = int.parse(versionNumbers[2]);
      final build = int.parse(buildPart);

      final result = Version(
        major: major,
        minor: minor,
        patch: patch,
        build: build,
      );
      debugPrint('[Version.parse] Successfully parsed: ${result.toString()}');
      return result;
    } catch (e) {
      debugPrint('[Version.parse] Parse error: $e');
      return null;
    }
  }

  /// Compare this version with another version
  /// Returns:
  /// - negative if this < other
  /// - 0 if this == other
  /// - positive if this > other
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return build.compareTo(other.build);
  }

  @override
  String toString() => '$major.$minor.$patch+$build';
}

/// Service for checking GitHub releases and version updates
class GitHubReleaseService {
  GitHubReleaseService({Dio? dio, SharedPreferences? prefs})
    : _dio = dio ?? Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  final Dio _dio;
  static const String _githubApiUrl =
      'https://api.github.com/repos/ringotypowriter/ringotrack/releases/latest';
  static const String _releasesUrl =
      'https://github.com/ringotypowriter/ringotrack/releases';
  static const String _lastCheckKey = 'lastUpdateCheck';
  static const String _latestVersionKey = 'latestVersion';
  static const Duration _checkInterval = Duration(hours: 12);

  /// Check if enough time has passed since last update check
  Future<bool> _shouldCheckForUpdates(SharedPreferences prefs) async {
    final lastCheckMs = prefs.getInt(_lastCheckKey);
    if (lastCheckMs == null) return true;

    final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMs);
    final now = DateTime.now();
    return now.difference(lastCheck) >= _checkInterval;
  }

  /// Update the last check timestamp
  Future<void> _updateLastCheckTime(SharedPreferences prefs) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_lastCheckKey, now);
  }

  /// Store the latest version result
  Future<void> _storeLatestVersion(
    SharedPreferences prefs,
    Version? version,
  ) async {
    if (version != null) {
      await prefs.setString(_latestVersionKey, version.toString());
    } else {
      await prefs.remove(_latestVersionKey);
    }
  }

  /// Get the stored latest version
  Version? _getStoredLatestVersion(SharedPreferences prefs) {
    final versionString = prefs.getString(_latestVersionKey);
    if (versionString != null) {
      return Version.parse(versionString);
    }
    return null;
  }

  /// Check for updates and return the latest version info
  /// Returns null if no update is available or if check should be skipped
  Future<Version?> checkForUpdates(
    Version currentVersion,
    SharedPreferences prefs, {
    bool forceCheck = false,
  }) async {
    debugPrint(
      '[GitHubReleaseService] Starting update check (force: $forceCheck)',
    );
    debugPrint(
      '[GitHubReleaseService] Current version: ${currentVersion.toString()}',
    );

    // If not forcing check, return stored result if available and still newer
    if (!forceCheck) {
      final storedVersion = _getStoredLatestVersion(prefs);
      if (storedVersion != null) {
        final comparison = storedVersion.compareTo(currentVersion);
        if (comparison > 0) {
          debugPrint(
            '[GitHubReleaseService] Returning stored newer version: ${storedVersion.toString()}',
          );
          return storedVersion;
        } else {
          debugPrint(
            '[GitHubReleaseService] Stored version is not newer, clearing',
          );
          await _storeLatestVersion(prefs, null);
        }
      }
    }

    // Check if we should perform the update check
    final shouldCheck = forceCheck || await _shouldCheckForUpdates(prefs);
    debugPrint('[GitHubReleaseService] Should check for updates: $shouldCheck');

    if (!shouldCheck) {
      debugPrint('[GitHubReleaseService] Skipping update check due to cache');
      return null;
    }

    try {
      debugPrint(
        '[GitHubReleaseService] Making API request to: $_githubApiUrl',
      );
      final response = await _dio.get(_githubApiUrl);
      debugPrint(
        '[GitHubReleaseService] API response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final tagName = data['tag_name'] as String?;
        debugPrint('[GitHubReleaseService] GitHub tag_name: $tagName');

        if (tagName != null) {
          final latestVersion = Version.parse(tagName);
          debugPrint(
            '[GitHubReleaseService] Parsed latest version: ${latestVersion?.toString() ?? 'null'}',
          );

          if (latestVersion != null) {
            // Update last check time
            await _updateLastCheckTime(prefs);
            debugPrint('[GitHubReleaseService] Updated last check timestamp');

            // Compare versions
            final comparison = latestVersion.compareTo(currentVersion);
            debugPrint(
              '[GitHubReleaseService] Version comparison result: $comparison (1=newer, 0=equal, -1=older)',
            );

            if (comparison > 0) {
              debugPrint(
                '[GitHubReleaseService] New version available: ${latestVersion.toString()}',
              );
              await _storeLatestVersion(prefs, latestVersion);
              return latestVersion;
            } else {
              debugPrint('[GitHubReleaseService] No update available');
              await _storeLatestVersion(prefs, null);
            }
          } else {
            debugPrint(
              '[GitHubReleaseService] Failed to parse version from tag: $tagName',
            );
          }
        } else {
          debugPrint(
            '[GitHubReleaseService] No tag_name found in API response',
          );
        }
      } else {
        debugPrint(
          '[GitHubReleaseService] API request failed with status: ${response.statusCode}',
        );
      }

      // Update last check time even on failure to avoid spam
      await _updateLastCheckTime(prefs);
      // Don't clear stored version on API failure - keep the last known good result
      debugPrint(
        '[GitHubReleaseService] Updated last check timestamp (failure case)',
      );
      return null;
    } catch (e) {
      debugPrint('[GitHubReleaseService] Error during update check: $e');
      // On network errors, still update the timestamp to avoid immediate retries
      await _updateLastCheckTime(prefs);
      debugPrint(
        '[GitHubReleaseService] Updated last check timestamp (error case)',
      );
      return null;
    }
  }

  /// Get the releases URL for redirecting users
  String get releasesUrl => _releasesUrl;
}

/// Exception thrown when version parsing fails
class VersionParseException implements Exception {
  const VersionParseException(this.message);
  final String message;

  @override
  String toString() => 'VersionParseException: $message';
}
