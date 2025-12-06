# RingoTrack

<p align="center">
  <img src="docs/screenshot.jpg" alt="RingoTrack Screenshot" width="600"/>
</p>

> 跨平台绘画时间追踪工具，用 GitHub 风格日历热力图记录创作习惯

RingoTrack 是一个基于 Flutter 的桌面应用程序，自动统计绘画软件使用时长，并通过类似 GitHub contributions 的日历热力图展示绘画活跃度。

支持 **Windows / macOS** 双平台，以 **Apache 2.0 协议** 开源。

<details>
<summary>📖 开发动机小故事</summary>

最初的想法来自一次闲聊：  
聊到 GitHub 的小绿砖热力图时，觉得那种「用一整面墙记录长期投入」的方式很适合用在绘画这类需要长期练习的事情上。

但现成的工具更多是面向写代码或记录工作时间，很少有专门为画师做、同时支持 Windows 和 macOS 的简单小工具。

RingoTrack 就是在这个背景下做出来的：  
把前台绘画软件的使用时长统计下来，用一块类似 GitHub contributions 的日历热力图，安静地记录你画画的频率和节奏。
</details>

## ✨ 核心功能

- **自动计时**：后台监听前台窗口，只对绘画软件计时
- **AFK 检测**：智能检测离开状态，避免无效时间计入统计
- **热力图展示**：GitHub 风格日历热力图，颜色深浅映射时长
- **多视图分析**：总览视图、按软件视图、趋势分析
- **隐私友好**：所有数据保存在本地，不上传服务器

## 🚀 快速开始

### Windows 用户
1. 前往 [Releases 页面](https://github.com/ringotypowriter/ringotrack/releases) 下载最新版本
2. 启动 RingoTrack 并保持在后台运行

### 从源码构建
```bash
git clone https://github.com/ringotypowriter/ringotrack.git
cd ringotrack
flutter pub get

# Windows
flutter run -d windows

# macOS
flutter run -d macos
```

**环境要求**：Flutter 3.38.3+，已开启桌面平台支持

## 📖 使用说明

1. 启动 RingoTrack 并保持在后台运行
2. 正常使用绘画软件（Photoshop、CLIP STUDIO PAINT 等）
3. 打开仪表盘查看：
   - 今日/本周/本月绘画时长
   - 连续绘画天数
   - 日历热力图（总览/按软件视图）
   - 趋势分析和统计图表

在「偏好设置」中可以：
- 管理绘画软件列表
- 调整主题色
- 删除特定数据或清空记录

## ❓ 常见问题

**Q: Windows 下程序无法运行或闪退？**  
A: 通常是由于中文路径问题，请将程序移动到英文路径下运行。

**Q: 绘画软件没有被记录？**  
A: 确认软件已在设置列表中，且 RingoTrack 正在后台运行。

**Q: 数据会上传吗？**  
A: 不会，所有数据都保存在本地。

## 🛠️ 开发与贡献

欢迎提交 Issue 或 Pull Request：

```bash
# 安装依赖
flutter pub get

# 运行测试
flutter test

# 代码检查
flutter analyze
```

## 📄 许可证

Apache License 2.0 - 详见 [LICENSE](LICENSE) 文件
