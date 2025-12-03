# Ringotrack 初始产品设计文档

## 1. 产品一句话

一个专门为 **绘画用户** 做的「跨平台（Windows + macOS）应用使用时间统计」工具，  
用类似 GitHub contributions 小绿砖 的日历热力图，直观展示你在各类绘画软件里的创作习惯和投入度。

---

## 2. 核心设计概念：小绿砖时间热力图

### 2.1 可视化形态

- 整体视觉基因参考 GitHub 小绿砖。
- 横轴：日期（按天，支持一年视图 / 多月视图）。
- 纵轴：
  - 按总量视图：星期（类 GitHub）。
  - 按软件视图：不同的软件分多行（例如：PS 一行、CSP 一行、Krita 一行）。
- 每格代表：某天在某个绘画软件上的 **累计前台使用时长**。
- 颜色深度 = 使用时长强度：
  - 浅色：随便点开了一会儿。
  - 中色：有认真画一段时间。
  - 深色：沉浸创作好几个小时。
- 交互：
  - hover / 悬停：展示该格对应的日期 + 时长（总时长 / 各软件时长）。
  - 点击：弹出详情（当天的使用时间分布，可视化为时间轴或列表）。

### 2.2 视图模式

- 按软件视图：
  - 每个绘画软件一行砖墙（PS、CSP、SAI、Krita 等）。
  - 支持快速对比不同软件的使用频率和强度。
- 按总量视图：
  - 合并所有绘画软件，只看整体「画画活跃度」。
  - 形态接近 GitHub contributions。
- 分组视图（可选）：
  - 「绘画主力」：PS、CSP、SAI 等。
  - 「辅助工具」：PureRef、参考图浏览器等。

### 2.3 核心价值

用户一眼就能看到：

- 哪几天有画画，哪几天完全没碰。
- 自己是「周末战士」还是「工作日晚间练习型」。
- 哪个软件是主力（砖最多、颜色最深）。
- 自己的创作习惯在过去一个月 / 一年里的变化趋势。

---

## 3. 目标用户 & 使用场景

### 3.1 目标用户

- 使用 SAI / Photoshop / CLIP STUDIO PAINT / Krita 等进行创作的：
  - 插画师
  - 漫画家
  - 原画师
  - 兴趣绘画用户 / 学生

### 3.2 要解决的核心问题

- 「我到底花了多少时间在画画上？」
- 「我说自己每天画画，实际上有做吗？」
- 「我在哪个软件上花时间最多？」
- 「我近期画画的节奏是在变好，还是在变差？」

### 3.3 典型使用场景

- 每天结束的时候：
  - 打开 App，看一眼今天的小绿砖，有没有空白（没画画）。
- 回顾过去一个月 / 一年：
  - 看到自己创作习惯的变化（高频期 / 低谷期）。
  - 对比不同绘画软件的投入变化（从 PS 转移到 CSP 等）。
- 调整学习 / 工作计划：
  - 用小绿砖作为「打卡感」反馈，对自己形成正向激励。

---

## 4. 平台与底层技术方案

整体是一个 **跨平台（Windows + macOS）的桌面应用**，前端使用 Flutter，底层通过系统 API 采集前台应用使用时间。

### 4.1 数据统一目标

- 对 UI 和业务层暴露统一的数据结构：
  - `Map<Date, Map<AppId, Duration>>`
- Windows 与 macOS 在底层采集方式不同，但在 **AppId 维度统一到字符串标识**：
  - Windows：`appId = exe 名`（例如：`Photoshop.exe`、`CLIPStudioPaint.exe`）。
  - macOS：`appId = bundleId`（例如：`com.adobe.photoshop`、`jp.co.celsys.clipstudiopaint`）。
- UI 层只关心：
  - 某一天
  - 某个 appId
  - 累计使用时长

### 4.2 Windows 端：基于前台窗口进程的时间采集

- 技术栈：**Flutter + win32 (Dart FFI)**。
- 核心流程：
  1. 通过 `GetForegroundWindow()` 获取当前前台窗口句柄。
  2. 使用 `GetWindowThreadProcessId()` 获取对应进程 PID。
  3. `OpenProcess()` + `GetModuleFileNameEx()` 获取 exe 路径 / 名称。
  4. 使用 exe 名作为 `appId`（例如：`Photoshop.exe`）。
  5. 在 Dart 层以固定频率或事件驱动进行采样：
     - 默认每秒轮询一次前台窗口。
     - 获取当前前台进程对应的 `appId`。
     - 判断该 `appId` 是否在「绘画软件列表」中。
     - 如果是，则对「当前日期 + appId」的累计时长 `+1 秒`。
- 数据落地形式（示意）：
  ```dart
  Map<DateTime, Map<String, Duration>> usage;
  // 例：usage[2025-01-01]['Photoshop.exe'] = 3h 20m
  ```

### 4.3 macOS 端：基于前台 App 通知的时间采集

- 技术栈：**Flutter 插件 + Swift + AppKit**。
- 核心流程：
  1. 使用 `NSWorkspace.shared.frontmostApplication` 获取当前前台 App。
  2. 监听 `NSWorkspace.didActivateApplicationNotification`，在前台 App 变化时触发事件。
  3. 从 `NSRunningApplication` 中获取：
     - `bundleIdentifier`（作为 `appId`）。
     - `localizedName`（用于展示）。
  4. 通过 Flutter 的 `EventChannel` 将「前台 App 变化事件」推送到 Dart 侧。
  5. Dart 侧维护一个「当前前台 appId + 进入前台时间」：
     - 当前 app 进入前台时记录时间戳 `t_enter`。
     - 下一个 App 进入前台时，以当前时间 `t_now - t_enter` 作为该 app 的本次前台时长。
     - 如果 `appId` 在「绘画软件列表」中，则将这段时长累加到对应日期。
- 数据结构保持与 Windows 一致：
  - `appId = bundleId`
  - 对外统一为 `Map<Date, Map<AppId, Duration>>`

---

## 5. 数据模型与存储

### 5.1 核心数据结构

- 基础模型：
  - `Date`：按本地时间的自然日（00:00–24:00）。
  - `AppId`：应用唯一标识（Windows 为 exe 名，macOS 为 bundleId）。
  - `Duration`：该日期内，该 App 的累积前台时长。
- 统一表示：
  ```text
  UsageByDate = Map<Date, UsagePerApp>
  UsagePerApp = Map<AppId, Duration>
  ```

### 5.2 持久化方案（初版）

- 本地嵌入式存储（例如：SQLite / 本地文件 JSON），优先简单可靠。
- 按日期增量写入：
  - 每日使用时实时累加在内存中。
  - 定期（或应用退出时）写回持久化。
- 为可视化场景优化的查询：
  - 按时间范围查询（例如：最近 30 天 / 最近 365 天）。
  - 按 AppId 过滤或聚合。

---

## 6. 配置与分类：专注“绘画软件砖墙”

### 6.1 内置规则

- 内置一批常见绘画软件的识别规则：
  - Windows：常见绘画软件 exe 名。
  - macOS：常见绘画软件 bundleId。
- 示例（非完整列表）：
  - Photoshop
  - CLIP STUDIO PAINT
  - SAI
  - Krita
  - Medibang Paint
  - 以及常见辅助类工具（如参考图软件）。

### 6.2 用户自定义配置

- 在 UI 中提供简单直观的管理入口：
  - 「一键把当前前台应用加入为绘画软件」。
  - 查看已加入的「目标绘画软件列表」。
  - 支持重命名展示名称（例如：把 `Photoshop.exe` 显示为「Photoshop」）。
- 分类 / 分组（可选）：
  - 「绘画主力」：PS、CSP、SAI 等。
  - 「辅助工具」：PureRef、参考图浏览器等。

### 6.3 视图层对应

- 所有绘画软件合并视图：
  - 将所有标记为「绘画软件」的 AppId 的时长相加。
  - 以单一小绿砖墙展示整体创作活跃度。
- 按单个软件分行视图：
  - 每个 AppId 一行。
  - 支持横向对比不同软件的创作投入。
- 分组视图：
  - 「主力 vs 辅助」两组或多组。
  - 每组内部可按 AppId 再细分。

---

## 7. 可视化与交互设计（初版）

### 7.1 小绿砖日历视图

- 时间范围选择：
  - 最近 30 天
  - 最近 90 天
  - 最近 365 天
- 颜色映射：
  - 0 使用时间：无砖 / 极浅色。
  - 少量：浅色。
  - 中等：中间色。
  - 超长时间：深色。
  - 初版可使用固定阈值，后续可引入「以个人历史为基准的自适应阈值」。

### 7.2 交互细节

- Hover：
  - 显示日期、总时长。
  - 在按软件视图下显示对应软件的时长。
- 点击：
  - 打开当天详情：
    - 按时间段的使用分布（近似时间轴）。
    - 当天各软件的占比饼图 / 条形图（可选）。
- 过滤与切换：
  - 视图切换：总量 / 单软件 / 分组。
  - App / 分组筛选。

---

## 8. 项目整体定义（总结版）

Ringotrack 是一个 **跨平台（Windows + macOS）的绘画软件使用时长追踪工具**。

- 底层通过系统 API 采集前台应用的准确时间数据：
  - Windows 通过 win32 API 获取前台窗口对应进程，进而获得 exe 名。
  - macOS 通过 NSWorkspace 通知机制获取前台 App 的 bundleId。
- 上层统一成 `Map<Date, Map<AppId, Duration>>` 的数据结构。
- 在前端用 **GitHub 小绿砖风格的日历热力图** 展示：
  - 每天的创作活跃度。
  - 不同绘画软件的使用分布。

目标是：  
让绘画用户可以「看见自己的创作习惯」，  
用一堵「画画小绿砖墙」记录自己的成长。

