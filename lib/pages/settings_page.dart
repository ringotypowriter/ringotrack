import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ringotrack/domain/drawing_app_preferences.dart';
import 'package:ringotrack/domain/drawing_app_preferences_controller.dart';
import 'package:ringotrack/providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _addAppController = TextEditingController();
  final TextEditingController _deleteAppController = TextEditingController();

  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void dispose() {
    _addAppController.dispose();
    _deleteAppController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1440.w, maxHeight: 900.h),
          child: Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(theme, context),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 64.w,
                      vertical: 40.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '设置',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 24.h),
                        _buildSettingsContent(theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 64.w, vertical: 18.h),
      child: Row(
        children: [
          Container(
            width: 10.r,
            height: 10.r,
            decoration: const BoxDecoration(
              color: Color(0xFF4AC26B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '设置',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('返回仪表盘'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent(ThemeData theme) {
    final prefsAsync = ref.watch(drawingAppPrefsControllerProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '基础设置',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: const Color(0xFFE3E3E3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '追踪的软件列表',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '配置需要统计的绘画软件（bundleId / exe 名）。仅这些软件会被计入使用时长。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 16.h),
                prefsAsync.when(
                  data: (prefs) => _buildTrackedList(theme, prefs),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (err, _) => Text(
                    '加载失败: $err',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.red,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addAppController,
                        decoration: const InputDecoration(
                          labelText: '新增软件 bundleId / exe 名',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _onAddTrackedApp(),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    ElevatedButton(
                      onPressed: _onAddTrackedApp,
                      child: const Text('添加'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 32.h),
          Text(
            '数据管理',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: const Color(0xFFE3E3E3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '删除某个软件的数据',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _deleteAppController,
                        decoration: const InputDecoration(
                          labelText: '软件 bundleId / exe 名',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    OutlinedButton(
                      onPressed: _onDeleteAppData,
                      child: const Text('删除该软件数据'),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                const Divider(height: 24),
                Text(
                  '删除日期范围内的数据（全部软件）',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 12.w,
                  runSpacing: 12.h,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => _pickDate(isStart: true),
                      child: Text(_formatDate(_rangeStart, label: '开始日期')),
                    ),
                    OutlinedButton(
                      onPressed: () => _pickDate(isStart: false),
                      child: Text(_formatDate(_rangeEnd, label: '结束日期')),
                    ),
                    ElevatedButton(
                      onPressed: _onDeleteDateRange,
                      child: const Text('删除日期范围数据'),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                const Divider(height: 24),
                Row(
                  children: [
                    Text(
                      '清空全部数据',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _onClearAll,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('清空'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackedList(ThemeData theme, DrawingAppPreferences prefs) {
    if (prefs.trackedAppIds.isEmpty) {
      return Text(
        '当前未配置软件，将使用默认列表。',
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
      );
    }

    final sorted = prefs.trackedAppIds.toList()..sort();

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final appId in sorted)
          Chip(
            label: Text(appId),
            onDeleted: () => _onRemoveTrackedApp(appId),
          ),
      ],
    );
  }

  Future<void> _onAddTrackedApp() async {
    final text = _addAppController.text.trim();
    if (text.isEmpty) return;

    final notifier = ref.read(drawingAppPrefsControllerProvider.notifier);
    await notifier.addApp(text);
    _addAppController.clear();
    _showSnack('已添加：$text');
  }

  Future<void> _onRemoveTrackedApp(String appId) async {
    final notifier = ref.read(drawingAppPrefsControllerProvider.notifier);
    await notifier.removeApp(appId);
    _showSnack('已移除：$appId');
  }

  Future<void> _onDeleteAppData() async {
    final appId = _deleteAppController.text.trim();
    if (appId.isEmpty) return;

    final repo = ref.read(usageRepositoryProvider);
    await repo.deleteByAppId(appId);
    ref.invalidate(yearlyUsageByDateProvider);
    _showSnack('已删除 $appId 的数据');
  }

  Future<void> _onDeleteDateRange() async {
    if (_rangeStart == null || _rangeEnd == null) {
      _showSnack('请先选择开始和结束日期');
      return;
    }

    final repo = ref.read(usageRepositoryProvider);
    await repo.deleteByDateRange(_rangeStart!, _rangeEnd!);
    ref.invalidate(yearlyUsageByDateProvider);
    _showSnack('已删除 ${_formatDate(_rangeStart)} 至 ${_formatDate(_rangeEnd)} 的数据');
  }

  Future<void> _onClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认清空所有数据？'),
          content: const Text('此操作不可撤销，会删除所有已记录的使用时长。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final repo = ref.read(usageRepositoryProvider);
    await repo.clearAll();
    ref.invalidate(yearlyUsageByDateProvider);
    _showSnack('所有数据已清空');
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? (_rangeStart ?? now) : (_rangeEnd ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _rangeStart = picked;
      } else {
        _rangeEnd = picked;
      }
    });
  }

  String _formatDate(DateTime? date, {String label = ''}) {
    if (date == null) return label.isEmpty ? '未选择' : label;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
