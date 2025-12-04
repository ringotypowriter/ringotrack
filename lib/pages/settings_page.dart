import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ringotrack/domain/drawing_app_preferences.dart';
import 'package:ringotrack/domain/drawing_app_preferences_controller.dart';
import 'package:ringotrack/providers.dart';

const _accent = Color(0xFF2CB36B);
const _deepAccent = Color(0xFF1F7A4A);
const _cardBorder = Color(0xFFE1E7DF);

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
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1440.w, maxHeight: 900.h),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(theme, context),
                SizedBox(height: 16.h),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 18.h),
                        _buildSettingsGrid(theme),
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
    return Row(
      children: [
        Container(
          width: 12.r,
          height: 12.r,
          decoration: const BoxDecoration(
            color: _accent,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          '偏好设置',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: const Color(0xFF1C2B20),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('返回仪表盘'),
        ),
      ],
    );
  }

  Widget _pillStat(String text, IconData icon, Color iconColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          SizedBox(width: 6.w),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSettingsGrid(ThemeData theme) {
    final prefsAsync = ref.watch(drawingAppPrefsControllerProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1080;
        final cardWidth = isWide
            ? (constraints.maxWidth - 16.w) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 16.w,
          runSpacing: 16.h,
          children: [
            SizedBox(
              width: cardWidth,
              child: _sectionCard(
                theme,
                title: '追踪的软件',
                subtitle: '仅列出的软件会计入时长，支持 bundleId / exe 名，自动大小写忽略。',
                icon: Icons.brush_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    prefsAsync.when(
                      data: (prefs) => _buildTrackedList(theme, prefs),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(minHeight: 4),
                      ),
                      error: (err, _) => _errorText(theme, '加载失败: $err'),
                    ),
                    SizedBox(height: 14.h),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _addAppController,
                            decoration: const InputDecoration(
                              labelText: '新增 bundleId / exe',
                              prefixIcon: Icon(Icons.add_circle_outline),
                            ),
                            onSubmitted: (_) => _onAddTrackedApp(),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        FilledButton.icon(
                          onPressed: _onAddTrackedApp,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('添加'),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      '内置参考',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF4C5A52),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        for (final appId in defaultTrackedAppIds)
                          _ghostChip(appId),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _sectionCard(
                theme,
                title: '数据管理',
                subtitle: '按软件清理、按日期删除或一次性清空，操作不可撤销。',
                icon: Icons.storage_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dataTile(
                      theme,
                      title: '删除某个软件的数据',
                      helper: '输入 bundleId / exe 名，大小写忽略。',
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _deleteAppController,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.apps_outlined),
                                labelText: '软件标识',
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          OutlinedButton.icon(
                            onPressed: _onDeleteAppData,
                            icon: const Icon(
                              Icons.delete_sweep_outlined,
                              size: 18,
                            ),
                            label: const Text('删除数据'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),
                    _dataTile(
                      theme,
                      title: '删除日期范围（全部软件）',
                      helper: '选择起止日期后执行。',
                      child: Wrap(
                        spacing: 10.w,
                        runSpacing: 10.h,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _pickDate(isStart: true),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              _formatDate(_rangeStart, label: '开始日期'),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _pickDate(isStart: false),
                            icon: const Icon(Icons.event, size: 16),
                            label: Text(_formatDate(_rangeEnd, label: '结束日期')),
                          ),
                          FilledButton.icon(
                            onPressed: _onDeleteDateRange,
                            icon: const Icon(
                              Icons.cleaning_services_outlined,
                              size: 18,
                            ),
                            label: const Text('删除范围'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),
                    _dataTile(
                      theme,
                      title: '清空全部数据',
                      helper: '危险操作，请确认后执行。',
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _onClearAll,
                          icon: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                          ),
                          label: const Text('清空记录'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 10.h,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionCard(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required Widget child,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: _deepAccent),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1B2B20),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF4C5A52),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          child,
        ],
      ),
    );
  }

  Widget _dataTile(
    ThemeData theme, {
    required String title,
    required String helper,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F2),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D2C21),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            helper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF516157),
            ),
          ),
          SizedBox(height: 10.h),
          child,
        ],
      ),
    );
  }

  Widget _ghostChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFB9D6C5)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF1F2B24),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _errorText(ThemeData theme, String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFFFC5C1)),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red[700]),
      ),
    );
  }

  Widget _buildTrackedList(ThemeData theme, DrawingAppPreferences prefs) {
    if (prefs.trackedAppIds.isEmpty) {
      return Text(
        '当前未配置软件，将使用默认列表。',
        style: theme.textTheme.bodySmall?.copyWith(
          color: const Color(0xFF4C5A52),
        ),
      );
    }

    final sorted = prefs.trackedAppIds.toList()..sort();

    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: [
        for (final appId in sorted)
          InputChip(
            label: Text(appId),
            labelStyle: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF1F2B24),
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: _accent.withOpacity(0.1),
            deleteIconColor: _deepAccent,
            side: const BorderSide(color: Color(0xFFB9D6C5)),
            onDeleted: () => _onRemoveTrackedApp(appId),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
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
    _showSnack(
      '已删除 ${_formatDate(_rangeStart)} 至 ${_formatDate(_rangeEnd)} 的数据',
    );
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
