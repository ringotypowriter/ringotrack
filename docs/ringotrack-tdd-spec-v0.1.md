# RingoTrack v0.1 TDD 规格说明（以测试用例为起点）

> 本文档优先从「测试用例 + 预期效果」出发，为后续 TDD 开发服务。  
> v0.1 聚焦两个核心能力：  
> 1）采集并统计绘画软件使用时长；2）用小绿砖日历热力图展示最近一年的活跃度。

---

## 0. 当前实现进度概览（截至 2025-12-04）

### 0.1 Feature 级 Test Case 状态

| 用例 | 描述 | 状态 | 主要实现 / 测试位置 |
| ---- | ---- | ---- | -------------------- |
| TC-F-01 ~ TC-F-05 | 采集并统计绘画软件使用时长（单 app、多次会话、跨天、过滤、动态配置） | ✅ 核心逻辑已通过单元测试 | `UsageAggregator`（`lib/domain/usage_models.dart`）、`UsageService`、`test/usage_aggregator_test.dart` |
| TC-F-06 | 最近 30 天 / 全年合并视图渲染 | 🟡 基础渲染已完成，细节交互待补 | `RingoHeatmap`、`DashboardPage`、`test/ringo_heatmap_test.dart` |
| TC-F-07 | 按软件分行视图渲染 | 🟡 app 维度数据与 UI 架子已具备 | `DashboardPage._buildHeatmapShell`，后续需补充「一行一 app」布局与交互测试 |
| TC-F-08 | 当日详情弹窗 | ⚪ 未实现 | 需补充日详情弹窗组件 + 对应 widget test |
| TC-F-09 | 无数据时的空状态 | 🟡 日历空状态文案已在 `RingoHeatmap` 调用处实现 | `DashboardPage._buildHeatmapShell`；可再补充 Golden / widget test 覆盖 |

> 状态说明：✅ 已实现并有测试；🟡 主要逻辑已具备，仍有交互 / 样式 / 测试欠缺；⚪ 尚未实现。

### 0.2 技术模块进度

- 采集层（`ForegroundAppTracker`）
  - macOS：`_MacOsForegroundAppTracker` 通过 `EventChannel('ringotrack/foreground_app_events')` 与原生侧对接，负责监听前台 App 变化事件并记录日志；仍需在 Runner 中补齐插件注册和权限提示策略。
  - Windows：`_WindowsForegroundAppTracker` 已集成 FFI 轮询 `rt_get_foreground_app`，能够解析 exe 路径 / 标题 / pid，并做去抖；仍需完善 C 侧实现与错误码处理。
- 统计归并层（`UsageAggregator` / `UsageAnalysis`）
  - `UsageAggregator` 已完全实现跨天拆分、非绘画软件过滤、动态绘画软件集，并通过 `test/usage_aggregator_test.dart` 覆盖 TC-F-01 ~ TC-F-05。
  - `UsageAnalysis` 已提供按日、按周、按 app、按星期统计能力，并有对应单元测试（`test/usage_analysis_test.dart`）。
- 存储层（`UsageRepository` / Drift）
  - SQLite 仓储 `SqliteUsageRepository` 已完成增量 merge / 范围查询 / 删除等操作，测试用 in-memory DB 覆盖主要路径（`test/usage_repository_test.dart`）。
- 应用服务层（`UsageService`）
  - 已将 `ForegroundAppTracker` + `UsageAggregator` + `UsageRepository` 串联，并通过 Riverpod Provider 在应用启动时构建，支持实时 delta 推送给 UI（`usageServiceProvider` + `yearlyUsageByDateProvider`）。
- UI 层
  - Dashboard 主界面与 GitHub 风格热力图组件已经初步完成，并有部分 widget test（`test/ringo_heatmap_test.dart`）。
  - 设置 / 绘画软件页面的基本结构与偏好持久化逻辑已具备（`drawing_app_preferences*` 系列及其测试）。

### 0.3 v0.1 剩余工作清单（建议顺序）

1. 完成 Feature 级 UI 细节 & 交互  
   - [ ] TC-F-06：补齐「最近 30 天」与「全年」视图切换、hover tooltip 文案（与 `UsageAnalysis` 打通）。  
   - [ ] TC-F-07：在「按软件」视图中，将热力图布局改为「一行一个 app」，并支持按软件筛选 / 折叠。  
   - [ ] TC-F-08：实现「当日详情弹窗」组件，并用 widget test 验证数据正确性。  
   - [ ] TC-F-09：为热力图空状态补充 widget test / Golden test。  

2. 采集层与原生工程集成收尾  
   - [ ] 在 macOS Runner 中完成 `ringotrack/foreground_app_events` EventChannel 的发送逻辑与权限提示。  
   - [ ] 在 Windows C / DLL 层实现 `rt_get_foreground_app`，并与 `_RtForegroundAppInfo` 结构体对齐，同时补充基础日志。  

3. 产品体验打磨  
   - [ ] 仪表盘顶部时间范围选择器（7 天 / 30 天 / 365 天）对齐 `docs/product-design.md` 和 `docs/user_stories.md`。  
   - [ ] 「软件管理」页交互补全：当前前台应用一键加入为绘画软件、展示名编辑体验优化。  
   - [ ] 空状态 / 新手引导文案与 UI 风格对齐产品设计文档中的基调。  

> v0.1 之外的高级特性（SQLite 长期存储优化、多设备同步等），保持在项目级文档的「Future Enhancements」中规划，待 v0.1 稳定后再正式立项。

---

## 1. 测试用例总览（Feature 层）

### 1.1 Feature：记录绘画软件使用时长

**TC-F-01：只使用一个绘画软件的一天**

- 前置条件：
  - 已在「绘画软件列表」中添加 AppId：`Photoshop.exe`（Windows）或 `com.adobe.photoshop`（macOS）。
  - 系统本地日期为 `2025-01-01`。
- 操作步骤（模拟行为）：
  - 09:00 启动 RingoTrack 并开始后台记录。
  - 09:10 打开 Photoshop，并保持它为前台窗口。
  - 09:40 关闭 Photoshop，并切到其他非绘画软件（例如浏览器）。
- 预期结果：
  - 统计结果中，日期 `2025-01-01` 的 `Photoshop` 使用总时长为 **30 分钟**（±1 秒容差）。
  - 该日期在「合并视图」中有一块对应颜色的小绿砖，颜色等级为「中等」或以上。

---

**TC-F-02：多次切换同一个绘画软件**

- 前置条件：
  - AppId `CLIPStudioPaint.exe` 已配置为绘画软件。
  - 本地日期为 `2025-01-01`。
- 操作步骤：
  - 10:00 前台切入 CSP，绘画 20 分钟。
  - 10:20 切到浏览器 10 分钟。
  - 10:30 再切回 CSP，绘画 40 分钟。
  - 11:10 切到其他非绘画软件并保持。
- 预期结果：
  - 日期 `2025-01-01` 的 CSP 总时长为 **60 分钟**。
  - 数据模型中：
    - `usage[2025-01-01]['CLIPStudioPaint.exe'] == 60 min`。
  - 前端热力图中该日对应 CSP 的那一格颜色比 30 分钟时更深一档。

---

**TC-F-03：跨天使用绘画软件（00:00 边界）**

- 前置条件：
  - AppId `Krita.exe` 已配置为绘画软件。
  - 用户从 `2025-01-01 23:50` 开始绘画。
- 操作步骤：
  - 23:50：Krita 进入前台。
  - 23:50–23:59：保持前台。
  - 00:00–00:10：跨到 `2025-01-02`，仍保持前台。
  - 00:10：切换到其他应用。
- 预期结果：
  - 日期 `2025-01-01`：Krita 时长为 **10 分钟**。
  - 日期 `2025-01-02`：Krita 时长为 **10 分钟**。
  - 不允许将跨天时长全部算到同一天。

---

**TC-F-04：非绘画软件不会被计入**

- 前置条件：
  - 绘画软件列表为空，或仅包含与当前使用无关的软件。
- 操作步骤：
  - 连续 2 小时使用浏览器、视频播放器等非绘画软件。
- 预期结果：
  - 所有日期的统计结果中，绘画软件相关时长为 **0**。
  - 日历热力图完全为空白或极浅色（表示「无绘画活动」）。

---

**TC-F-05：用户在运行中把当前前台应用加入为绘画软件**

- 前置条件：
  - 当前前台应用为 `PureRef`，暂时未被标记为绘画软件。
  - 应用已运行，正在正常统计其他绘画软件。
- 操作步骤：
  - 用户在 UI 中点击「将当前前台应用加入为绘画软件」。
  - 后续保持 PureRef 为前台 30 分钟。
- 预期结果：
  - 加入操作之后的前台时长会计入当前日期的 PureRef。
  - 加入操作之前的历史时长不追溯统计（v0.1 简化）。

---

### 1.2 Feature：小绿砖日历热力图展示

**TC-F-06：最近 30 天合并视图渲染**

- 前置条件：
  - 数据库中已存在 30 天的使用数据，部分日期有非零时长。
- 操作步骤：
  - 打开 RingoTrack 主界面，切换到「最近 30 天 · 合并视图」。
- 预期结果：
  - 界面上显示连续 30 天的网格，每天一格。
  - 有绘画时长的日期显示为不同深浅的绿色。
  - 完全没有绘画活动的日期为无色或极浅背景色。
  - Hover 任意一格，会显示：
    - 日期
    - 当日总绘画时长（例如「2 小时 15 分钟」）。

---

**TC-F-07：按软件分行视图渲染**

- 前置条件：
  - 至少存在两个不同 AppId（例如 Photoshop 和 CSP）的有效数据。
- 操作步骤：
  - 切换到「按软件」视图。
- 预期结果：
  - 每个绘画软件对应一行小绿砖。
  - 同一天、不同软件的格子可以垂直对齐。
  - Hover 单个格子时，显示：
    - 日期
    - 软件名
    - 当日该软件时长（不显示其他软件的时长）。

---

**TC-F-08：当日详情弹窗**

- 前置条件：
  - 某一天存在多个软件的使用记录。
- 操作步骤：
  - 在任意视图中点击该日的格子。
- 预期结果：
  - 弹出当天详情面板，至少包含：
    - 当天所有绘画软件及各自总时长列表。
    - 当天总绘画时长。
  - v0.1 可以暂不实现时间轴可视化，只需保证数据正确。

---

**TC-F-09：无数据时的空状态**

- 前置条件：
  - 新安装的 RingoTrack，没有任何历史使用数据。
- 操作步骤：
  - 打开 App 主界面。
- 预期结果：
  - 日历区域显示为空状态提示：
    - 如「开始打开你喜欢的绘画软件，RingoTrack 会在这里记录你的创作小绿砖」。
  - 不出现错误提示或异常 UI 布局。

---

### 1.3 Feature：绘画软件配置管理

**TC-F-10：查看当前绘画软件列表**

- 操作步骤：
  - 打开「设置 / 绘画软件」页面。
- 预期结果：
  - 显示当前已标记为绘画软件的列表：
    - 包含 AppId（exe / bundleId）和展示名称。

---

**TC-F-11：重命名软件展示名称**

- 前置条件：
  - 列表中存在一个 AppId：`Photoshop.exe`，展示名称为「Photoshop」。
- 操作步骤：
  - 将展示名称修改为「PS」并保存。
- 预期结果：
  - 所有 UI 中展示的软件名统一更新为「PS」。
  - 底层 AppId 不变，统计数据不受影响。

---

## 2. 预期效果 Demo（概念层）

> 本节用文字描述预期 UI / 行为效果，作为设计与实现的共同参考。

### 2.1 主界面（最近 30 天 · 合并视图）

- 左上角：显示「RingoTrack」Logo 与当前视图标题，例如「最近 30 天 · 合并视图」。
- 主区域：
  - 一块类似 GitHub contributions 的日历：
    - 水平为日期（按周或按天折行）。
    - 每天一个方块，颜色从浅到深。
  - 鼠标悬停时：
    - 在方块上方或右侧出现悬浮卡片：
      - 标题：`2025-01-01`
      - 内容：`总绘画时间：2 小时 15 分钟`
- 底部：
  - 简单图例：从浅绿到深绿对应的时间范围区间。

### 2.2 按软件视图

- 顶部切换 Tab：
  - 「合并视图」 / 「按软件」 / 「分组视图（预留）」。
- 按软件视图中：
  - 每个软件一行，左侧显示软件图标 + 名称（如「Photoshop」）。
  - 右侧为该软件在选定时间范围内的小绿砖日历。
  - Hover 单格时：
    - 显示 `2025-01-01 · Photoshop · 45 分钟`。

### 2.3 设置 / 绘画软件页面

- 列表形式展示当前所有绘画软件：
  - 列：展示名称、AppId、平台（Win / macOS）。
  - 支持编辑展示名称。
- 顶部有一个按钮：
  - 「将当前前台应用加入为绘画软件」。
  - 点击后，在当前前台 AppId 不为空时：
    - 将其加入列表。
    - 默认展示名称为当前应用的 localizedName（macOS）或 exe 名简化版（Windows）。

---

## 3. 模块与测试分层（技术视角）

> 这一部分是为了方便写单元测试 / 集成测试时做分层规划。

### 3.1 采集层（Platform Tracker）

- 职责：
  - Windows：轮询前台窗口，推送「前台 App 变化事件」。
  - macOS：监听 `didActivateApplication`，推送「前台 App 变化事件」。
- 对 Dart 暴露统一事件流：
  - `ForegroundAppChanged(appId: String, timestamp: DateTime)`
- 单元测试方向（可通过模拟事件流实现）：
  - 给定一串 App 切换事件，输出的「使用时长统计」是否符合预期（对应上文 TC-F-01/02/03）。

### 3.2 统计归并层（Usage Aggregator）

- 输入：
  - 前台 App 进入 / 离开时间戳事件。
- 输出：
  - `Map<Date, Map<AppId, Duration>>`
- 关键测试点：
  - 跨天拆分（TC-F-03）。
  - 非绘画软件过滤（TC-F-04）。
  - 动态加入绘画软件后的行为（TC-F-05）。

### 3.3 存储层（Persistence）

- 职责：
  - 将 `UsageByDate` 增量写入本地存储。
  - 支持按日期范围读取统计数据。
- 测试点：
  - 写入后重新读取，数据一致。
  - 默认以「本地日期」为分区键，跨天数据拆分后写入正确日期。

### 3.4 UI 层（Flutter 组件）

- 单元测试 / Golden Test：
  - 给定固定的 `UsageByDate`：
    - 热力图颜色深浅符合配置阈值。
    - 空数据时显示空状态文案（TC-F-09）。
    - Hover / 点击交互触发正确的详情内容（可部分通过 widget test 模拟）。

---

## 4. 小结

- v0.1 目标非常明确：
  - 核心：**可靠的时间统计 + 清晰的小绿砖展示**。
- 本文档提供了：
  - 用例级别的 Feature 测试用例（TC-F-01 ~ TC-F-11）。
  - 对应的预期效果描述。
  - 模块分层和各层测试关注点。

后续可以基于这些 Test Case 先写测试，再按模块实现采集、统计、存储和 UI 渲染逻辑，实现一个小而精确的 RingoTrack v0.1。 
