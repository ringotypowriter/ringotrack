import 'dart:async';
import 'dart:io';

/// 单条日志记录
class AppLogEntry {
  AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  final DateTime timestamp;
  final String level; // DEBUG / INFO / WARN / ERROR
  final String tag;   // 模块名，比如 foreground_tracker_windows
  final String message;
}

/// 简单的文件 + 内存双通道日志服务，用于在 release 下调试采集逻辑。
class AppLogService {
  AppLogService._internal();

  static final AppLogService instance = AppLogService._internal();

  static const int _maxInMemoryEntries = 500;
  static const int _maxFileBytes = 1024 * 1024; // 1MB

  final List<AppLogEntry> _entries = <AppLogEntry>[];

  File? _logFile;
  bool _initializing = false;
  final List<Future<void> Function()> _pendingOperations = [];

  List<AppLogEntry> get entries => List.unmodifiable(_entries);

  Future<void> logDebug(String tag, String message) {
    return _log('DEBUG', tag, message);
  }

  Future<void> logInfo(String tag, String message) {
    return _log('INFO', tag, message);
  }

  Future<void> logWarn(String tag, String message) {
    return _log('WARN', tag, message);
  }

  Future<void> logError(String tag, String message) {
    return _log('ERROR', tag, message);
  }

  Future<void> _log(String level, String tag, String message) async {
    final timestamp = DateTime.now();
    final entry = AppLogEntry(
      timestamp: timestamp,
      level: level,
      tag: tag,
      message: message,
    );

    _entries.add(entry);
    if (_entries.length > _maxInMemoryEntries) {
      _entries.removeRange(0, _entries.length - _maxInMemoryEntries);
    }

    await _enqueueFileWrite(timestamp, level, tag, message);
  }

  Future<void> _enqueueFileWrite(
    DateTime timestamp,
    String level,
    String tag,
    String message,
  ) async {
    Future<void> operation() async {
      await _ensureInitialized();
      final file = _logFile;
      if (file == null) return;

      await _rotateIfNeeded(file);

      final ts = timestamp.toIso8601String();
      final line = '$ts [$level] [$tag] $message';
      await file.writeAsString('$line\n', mode: FileMode.append, flush: false);
    }

    if (_initializing) {
      _pendingOperations.add(operation);
      return;
    }

    await operation();
  }

  Future<void> _ensureInitialized() async {
    if (_logFile != null) return;
    if (_initializing) return;

    _initializing = true;
    try {
      final directory = _resolveLogDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File(_buildLogFilePath(directory.path));
      _logFile = file;

      // 执行初始化期间积压的写操作
      for (final op in _pendingOperations) {
        await op();
      }
      _pendingOperations.clear();
    } finally {
      _initializing = false;
    }
  }

  Directory _resolveLogDirectory() {
    final separator = Platform.pathSeparator;

    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      final base = appData?.isNotEmpty == true ? appData! : Directory.current.path;
      return Directory('$base${separator}RingoTrack${separator}logs');
    }

    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      final base = home?.isNotEmpty == true ? home! : Directory.current.path;
      return Directory('$base${separator}Library${separator}Application Support${separator}RingoTrack${separator}logs');
    }

    // 其他平台简单放到当前目录
    return Directory('logs');
  }

  String _buildLogFilePath(String dirPath) {
    final separator = Platform.pathSeparator;
    return '$dirPath${separator}tracking.log';
  }

  Future<void> _rotateIfNeeded(File file) async {
    try {
      if (!await file.exists()) return;
      final length = await file.length();
      if (length <= _maxFileBytes) return;

      final backup = File('${file.path}.1');
      if (await backup.exists()) {
        await backup.delete();
      }
      await file.rename(backup.path);
    } catch (_) {
      // 旋转失败不影响后续写入
    }
  }

  /// 清空内存与文件日志，方便在 UI 中一键清理
  Future<void> clear() async {
    _entries.clear();

    final file = _logFile;
    if (file != null && await file.exists()) {
      try {
        await file.writeAsString('');
      } catch (_) {
        // 忽略清空失败
      }
    }
  }
}
