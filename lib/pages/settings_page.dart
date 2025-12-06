import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ringotrack/domain/drawing_app_preferences.dart';
import 'package:ringotrack/domain/drawing_app_preferences_controller.dart';
import 'package:ringotrack/domain/dashboard_preferences.dart';
import 'package:ringotrack/domain/dashboard_preferences_controller.dart';
import 'package:ringotrack/providers.dart';
import 'package:ringotrack/theme/app_theme.dart';
import 'package:ringotrack/widgets/logs_view_sheet.dart';
import 'dart:io' show Platform;

const _cardBorder = Color(0xFFE1E7DF);

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _addAppController = TextEditingController();
  final ScrollController _trackedAppsScrollController = ScrollController();
  bool _isDataDangerExpanded = false;

  String? _selectedDeleteAppLogicalId;

  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void dispose() {
    _addAppController.dispose();
    _trackedAppsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Platform.isMacOS
          ? Colors.transparent
          : theme.colorScheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1440.w, maxHeight: 900.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(theme, context),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 40.w,
                    vertical: 32.h,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 18.h),
                        _buildSettingsGrid(theme),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme, BuildContext context) {
    final onSurface = theme.colorScheme.onSurface;

    final horizontal = 45.w;
    final topPadding = Platform.isMacOS ? 44.h : 24.h;
    final bottomPadding = Platform.isMacOS ? 26.h : 24.h;

    return Container(
      color: Platform.isMacOS ? Colors.transparent : theme.colorScheme.surface,
      padding: EdgeInsets.fromLTRB(
        horizontal,
        topPadding,
        horizontal,
        bottomPadding,
      ),
      child: Row(
        children: [
          if (!Platform.isMacOS) ...[
            Container(
              width: 12.r,
              height: 12.r,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 12.w),
          ],
          Text(
            '偏好设置',
            style:
                (Platform.isMacOS
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: onSurface,
                    ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('返回仪表盘'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGrid(ThemeData theme) {
    final prefsAsync = ref.watch(drawingAppPrefsControllerProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionCard(
              theme,
              title: '主题色',
              icon: Icons.palette_outlined,
              child: _buildThemePicker(theme),
            ),
            SizedBox(height: 16.h),
            _rangeModeSection(theme),
            SizedBox(height: 16.h),
            _trackingSection(theme, prefsAsync),
            SizedBox(height: 16.h),
            _dataSection(theme, prefsAsync),
          ],
        );
      },
    );
  }

  Widget _trackingSection(
    ThemeData theme,
    AsyncValue<DrawingAppPreferences> prefsAsync,
  ) {
    return _sectionCard(
      theme,
      title: '追踪的软件',
      icon: Icons.brush_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dataTile(
            theme,
            title: '已追踪的软件',
            helper: '仅下列软件计时，留空用默认列表。',
            child: prefsAsync.when(
              data: (prefs) => _buildTrackedList(theme, prefs),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(minHeight: 4),
              ),
              error: (err, _) => _errorText(theme, '加载失败: $err'),
            ),
          ),
          SizedBox(height: 14.h),
          _dataTile(
            theme,
            title: '添加新软件',
            helper:
                '优先用“内置列表”。未包含时输入系统识别名（如 Photoshop.exe / com.adobe.photoshop）。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addAppController,
                        decoration: const InputDecoration(
                          labelText: '软件名称或系统识别名',
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
                SizedBox(height: 10.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _showBuiltInAppPicker,
                    icon: const Icon(Icons.list_alt_outlined, size: 18),
                    label: const Text('从内置列表选择'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 8.h,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataSection(
    ThemeData theme,
    AsyncValue<DrawingAppPreferences> prefsAsync,
  ) {
    return _sectionCard(
      theme,
      title: '数据管理',
      icon: Icons.storage_rounded,
      child: _buildDataDangerArea(theme, prefsAsync),
    );
  }

  Widget _buildDataDangerArea(
    ThemeData theme,
    AsyncValue<DrawingAppPreferences> prefsAsync,
  ) {
    final dangerColor = theme.colorScheme.error;
    final dangerBackground = dangerColor.withValues(alpha: 0.08);
    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: dangerBackground,
          borderRadius: BorderRadius.circular(12.r),
          child: InkWell(
            borderRadius: BorderRadius.circular(12.r),
            onTap: () => setState(() {
              _isDataDangerExpanded = !_isDataDangerExpanded;
            }),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, color: dangerColor),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '危险区域',
                          style: titleStyle?.copyWith(color: dangerColor),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '包含不可逆的数据操作，请谨慎',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: dangerColor,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isDataDangerExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: dangerColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 14.h),
              ..._buildDataManagementTiles(theme, prefsAsync),
            ],
          ),
          crossFadeState: _isDataDangerExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeInOut,
          firstCurve: Curves.easeInOut,
          secondCurve: Curves.easeInOut,
        ),
      ],
    );
  }

  List<Widget> _buildDataManagementTiles(
    ThemeData theme,
    AsyncValue<DrawingAppPreferences> prefsAsync,
  ) {
    return [
      _dataTile(
        theme,
        title: '删除某个软件的数据',
        helper: '选择软件后清除全部记录。',
        child: prefsAsync.when(
          data: (prefs) => _buildDeleteByAppSelector(theme, prefs),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 4),
          ),
          error: (err, _) => _errorText(theme, '加载失败: $err'),
        ),
      ),
      SizedBox(height: 14.h),
      _dataTile(
        theme,
        title: '删除日期范围（全部软件）',
        helper: '选起止日期后删除。',
        child: Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickDate(isStart: true),
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_formatDate(_rangeStart, label: '开始日期')),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(isStart: false),
              icon: const Icon(Icons.event, size: 16),
              label: Text(_formatDate(_rangeEnd, label: '结束日期')),
            ),
            FilledButton.icon(
              onPressed: _onDeleteDateRange,
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: const Text('删除范围'),
            ),
          ],
        ),
      ),
      SizedBox(height: 14.h),
      _dataTile(
        theme,
        title: '清空全部数据',
        helper: '危险操作，不可撤销。',
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _onClearAll,
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
            label: const Text('清空记录'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            ),
          ),
        ),
      ),
      SizedBox(height: 14.h),
      _dataTile(
        theme,
        title: '日志',
        helper: '查看本地日志，排查问题。',
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _showLogsViewSheet,
            icon: const Icon(Icons.article_outlined),
            label: const Text('查看本地日志'),
          ),
        ),
      ),
    ];
  }

  Widget _sectionCard(
    ThemeData theme, {
    required String title,
    required Widget child,
    required IconData icon,
    String? subtitle,
  }) {
    final primary = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: primary),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _titleWithHelper(
                  theme,
                  title: title,
                  helper: subtitle,
                  titleStyle: theme.textTheme.titleMedium,
                  helperHeight: 1.35,
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
    final surfaceTint = theme.colorScheme.primary.withValues(alpha: 0.03);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: surfaceTint,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleWithHelper(theme, title: title, helper: helper),
          SizedBox(height: 10.h),
          child,
        ],
      ),
    );
  }

  Widget _errorText(ThemeData theme, String message) {
    final error = theme.colorScheme.error;
    final errorContainer = theme.colorScheme.errorContainer;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: errorContainer.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: errorContainer),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(color: error),
      ),
    );
  }

  Widget _buildTrackedList(ThemeData theme, DrawingAppPreferences prefs) {
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    if (prefs.trackedApps.isEmpty) {
      return _helperText(theme, '当前未配置软件，将使用内置默认列表。');
    }

    final sorted = [...prefs.trackedApps]
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 260.h),
      child: Scrollbar(
        controller: _trackedAppsScrollController,
        child: ListView.separated(
          controller: _trackedAppsScrollController,
          shrinkWrap: true,
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final app = sorted[index];
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: _cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28.r,
                    height: 28.r,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    alignment: Alignment.center,
                    child: app.iconAsset != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6.r),
                            child: Image.asset(
                              app.iconAsset!,
                              width: 22.r,
                              height: 22.r,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Text(
                            app.displayName.isNotEmpty
                                ? app.displayName.characters.first
                                : '?',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Builder(
                          builder: (context) {
                            final ids = app.ids;
                            if (ids.isEmpty) {
                              return _helperText(theme, '未配置平台标识');
                            }

                            final idTexts = ids
                                .map((id) => id.value)
                                .join(' · ');
                            return Text(
                              idTexts,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _onRemoveTrackedApp(app.logicalId),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    splashRadius: 18.r,
                    tooltip: '移除该软件',
                    color: primary,
                  ),
                ],
              ),
            );
          },
          separatorBuilder: (context, index) => SizedBox(height: 8.h),
        ),
      ),
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

  Future<void> _showBuiltInAppPicker() async {
    final currentPrefs =
        ref.read(drawingAppPrefsControllerProvider).value ??
        const DrawingAppPreferences(trackedApps: defaultTrackedApps);
    final initialTracked = currentPrefs.trackedApps
        .map((e) => e.logicalId)
        .toSet();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      builder: (context) {
        final theme = Theme.of(context);

        return Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 16.h,
            bottom: 12.h + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final allDefaults = [...defaultTrackedApps]
                ..sort((a, b) => a.displayName.compareTo(b.displayName));

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '从内置列表添加软件',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        splashRadius: 18.r,
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  _helperText(theme, '常见绘画软件，点“添加”即可。'),
                  SizedBox(height: 14.h),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final app in allDefaults)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8.h),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 8.h,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.03,
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(color: _cardBorder),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        app.displayName,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xFF1F2B24),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Builder(
                                      builder: (context) {
                                        final isAdded = initialTracked.contains(
                                          app.logicalId,
                                        );
                                        return TextButton(
                                          onPressed: isAdded
                                              ? null
                                              : () async {
                                                  final notifier = ref.read(
                                                    drawingAppPrefsControllerProvider
                                                        .notifier,
                                                  );
                                                  // 使用第一个 identifier 进行添加
                                                  final firstId =
                                                      app.ids.first.value;
                                                  await notifier.addApp(
                                                    firstId,
                                                  );
                                                  setModalState(() {
                                                    initialTracked.add(
                                                      app.logicalId,
                                                    );
                                                  });
                                                  _showSnack(
                                                    '已添加：${app.displayName}',
                                                  );
                                                },
                                          child: Text(isAdded ? '已添加' : '添加'),
                                        );
                                      },
                                    ),
                                  ],
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
          ),
        );
      },
    );
  }

  Widget _buildDeleteByAppSelector(
    ThemeData theme,
    DrawingAppPreferences prefs,
  ) {
    if (prefs.trackedApps.isEmpty) {
      return _helperText(theme, '当前没有配置追踪的软件，无法按软件删除数据。');
    }

    final apps = [...prefs.trackedApps]
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    final currentLogicalId =
        _selectedDeleteAppLogicalId ?? apps.first.logicalId;

    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260.w,
          child: DropdownButtonFormField<String>(
            initialValue: currentLogicalId,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.apps_outlined),
            ),
            items: [
              for (final app in apps)
                DropdownMenuItem(
                  value: app.logicalId,
                  child: Text(app.displayName),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedDeleteAppLogicalId = value;
              });
            },
          ),
        ),
        FilledButton.icon(
          onPressed: () => _onDeleteAppDataByLogicalId(apps, currentLogicalId),
          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
          label: const Text('删除数据'),
        ),
      ],
    );
  }

  Future<void> _onDeleteAppDataByLogicalId(
    List<TrackedApp> apps,
    String logicalId,
  ) async {
    final app = apps.firstWhere(
      (a) => a.logicalId == logicalId,
      orElse: () => apps[0],
    );

    if (app.ids.isEmpty) {
      _showSnack('该软件没有可识别的系统标识，无法删除数据');
      return;
    }

    final repo = ref.read(usageRepositoryProvider);
    for (final id in app.ids) {
      await repo.deleteByAppId(id.value);
    }
    ref.invalidate(yearlyUsageByDateProvider);
    _showSnack('已删除 ${app.displayName} 的所有数据');
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

  Widget _rangeModeSection(ThemeData theme) {
    final prefsAsync = ref.watch(dashboardPreferencesControllerProvider);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return _sectionCard(
      theme,
      title: '统计口径',
      icon: Icons.date_range_outlined,
      child: prefsAsync.when(
        data: (prefs) {
          final current = prefs.heatmapRangeMode;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<HeatmapRangeMode>(
                initialValue: current,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.timeline_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: HeatmapRangeMode.calendarYear,
                    child: Text('自然年（当年 1-12 月）'),
                  ),
                  DropdownMenuItem(
                    value: HeatmapRangeMode.rolling12Months,
                    child: Text('最近 12 个月（右侧为当前月）'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  ref
                      .read(dashboardPreferencesControllerProvider.notifier)
                      .setHeatmapRangeMode(value);
                },
              ),
              SizedBox(height: 8.h),
              Text(
                '仅影响热力图范围，今日/本周/本月仍按自然时间。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(minHeight: 4),
        ),
        error: (err, _) => _errorText(theme, '加载热力图偏好失败: $err'),
      ),
    );
  }

  Widget _buildThemePicker(ThemeData theme) {
    final themeAsync = ref.watch(appThemeProvider);
    final currentId = themeAsync.asData?.value.id ?? AppThemeId.ringoGreen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          children: [
            for (final t in availableThemes)
              _ThemeDot(
                theme: t,
                isSelected: t.id == currentId,
                onTap: () => ref.read(appThemeProvider.notifier).setTheme(t.id),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _showLogsViewSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      builder: (context) => const LogsViewSheet(),
    );
  }

  // 统一的标题/说明文本，避免重复样式定义
  Widget _titleText(ThemeData theme, String text, {TextStyle? style}) {
    return Text(
      text,
      style: (style ?? theme.textTheme.bodyMedium)?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _helperText(ThemeData theme, String text, {double height = 1.25}) {
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: height,
      ),
    );
  }

  Widget _titleWithHelper(
    ThemeData theme, {
    required String title,
    String? helper,
    TextStyle? titleStyle,
    double helperHeight = 1.25,
  }) {
    final hasHelper = helper != null && helper.isNotEmpty;
    if (!hasHelper) {
      return _titleText(theme, title, style: titleStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleText(theme, title, style: titleStyle),
        SizedBox(height: 8.h),
        _helperText(theme, helper, height: helperHeight),
      ],
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ThemeDot extends StatelessWidget {
  const _ThemeDot({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  final AppTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = isSelected ? theme.primary : Colors.grey.shade300;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48.r,
            height: 48.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 3),
              color: theme.primary.withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            theme.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
