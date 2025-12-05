import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ringotrack/domain/app_log_service.dart';

class LogsViewSheet extends StatefulWidget {
  const LogsViewSheet({super.key});

  @override
  State<LogsViewSheet> createState() => _LogsViewSheetState();
}

class _LogsViewSheetState extends State<LogsViewSheet> {
  final AppLogService _logService = AppLogService.instance;
  late List<AppLogEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _logService.entries;
  }

  Future<void> _refresh() async {
    setState(() {
      _entries = _logService.entries;
    });
  }

  Future<void> _clear() async {
    await _logService.clear();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _entries.reversed.toList(growable: false);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 16.h,
          bottom: 12.h + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '采集日志预览',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: '刷新',
                  splashRadius: 18.r,
                ),
                IconButton(
                  onPressed: _clear,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: '清空日志',
                  splashRadius: 18.r,
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '关闭',
                  splashRadius: 18.r,
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              '用于跨平台排查前台窗口采集与聚合写库的问题，最新记录在顶部。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF4C5A52),
              ),
            ),
            SizedBox(height: 14.h),
            SizedBox(
              height: 480.h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: _buildLogList(theme, entries),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogList(ThemeData theme, List<AppLogEntry> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          '当前还没有日志记录。请运行应用并切换前台软件后再查看。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFFCBD5F5),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Scrollbar(
      child: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final tsStr = entry.timestamp.toIso8601String();
          final levelColor = _levelColor(entry.level);

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120.w,
                  child: Text(
                    tsStr,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                SizedBox(
                  width: 52.w,
                  child: Text(
                    entry.level,
                    style: TextStyle(
                      color: levelColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                SizedBox(
                  width: 120.w,
                  child: Text(
                    entry.tag,
                    style: const TextStyle(
                      color: Color(0xFFBFDBFE),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: SelectableText(
                    entry.message,
                    style: const TextStyle(
                      color: Color(0xFFE5E7EB),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level.toUpperCase()) {
      case 'DEBUG':
        return const Color(0xFF38BDF8);
      case 'INFO':
        return const Color(0xFF4ADE80);
      case 'WARN':
        return const Color(0xFFFACC15);
      case 'ERROR':
        return const Color(0xFFF97373);
      default:
        return const Color(0xFFE5E7EB);
    }
  }
}
