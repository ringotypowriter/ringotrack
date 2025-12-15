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
  final String tag; // 模块名，比如 foreground_tracker_windows
  final String message;
}
