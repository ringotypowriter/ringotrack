# RingoTrack CI/CD 测试指南

## 概述
RingoTrack 项目现在包含了完整的自动化测试流程，确保代码质量和功能正确性。所有构建流程都会在构建前运行测试，测试失败将阻止构建进行。

## 测试工作流程

### 1. 独立测试工作流 (test.yml)
**触发条件:**
- 推送到 `main` 分支
- 创建 Pull Request 到 `main` 分支
- 手动触发 (`workflow_dispatch`)

**测试任务:**
- **Ubuntu 测试**: 运行代码分析和带覆盖率的测试
- **macOS 测试**: 在 macOS 环境运行测试
- **Windows 测试**: 在 Windows 环境运行测试

**步骤:**
1. 代码检出
2. Flutter 环境设置
3. 依赖安装 (`flutter pub get`)
4. 代码分析 (`flutter analyze`)
5. 运行测试 (`flutter test`)
6. 覆盖率报告上传 (Ubuntu 环境)

### 2. 构建工作流中的测试
所有构建工作流 (`build-all.yml`, `build-macos.yml`, `build-windows.yml`) 都只支持 **手动触发** (`workflow_dispatch`)，并且现在都包含强制性的测试步骤：

**触发方式:**
- 手动通过 GitHub Actions 界面触发
- 仅在工作流手动启动时运行

**构建流程:**
1. 代码检出
2. Flutter 环境设置
3. 平台特定配置启用
4. 依赖安装
5. **运行测试** (新增且必须通过)
6. 构建应用 (仅在测试通过后)

**关键特性:**
- 测试失败会阻止构建继续进行
- `continue-on-error: false` 确保严格的测试要求
- 测试必须在所有支持的平台 (Windows, macOS) 上通过
- 构建只能通过手动触发，提供了完全的控制权

## 测试覆盖率

### 当前测试文件
- `test/usage_aggregator_test.dart` - 核心聚合逻辑测试
- `test/usage_repository_test.dart` - 数据持久化测试
- `test/ringo_heatmap_test.dart` - UI 组件测试
- `test/usage_analysis_test.dart` - 使用分析测试
- `test/app_database_migration_test.dart` - 数据库迁移测试
- `test/usage_service_*.dart` - 服务层测试
- 其他多个测试文件...

### 运行本地测试
```bash
# 运行所有测试
flutter test

# 运行带覆盖率的测试
flutter test --coverage

# 运行代码分析
flutter analyze

# 运行特定测试文件
flutter test test/usage_aggregator_test.dart
```

## 测试策略

### 测试驱动开发 (TDD)
项目遵循 TDD 原则，主要测试场景包括：
- **TC-F-01**: 单个绘图应用会话跟踪
- **TC-F-02**: 同应用多会话处理
- **TC-F-03**: 跨天使用情况分割
- **TC-F-04**: 非绘图应用过滤
- **TC-F-05**: 动态应用配置

### 测试类型
1. **单元测试**: 测试核心业务逻辑
2. **集成测试**: 测试组件间交互
3. **Widget 测试**: 测试 Flutter UI 组件

## GitHub Actions 配置

### 测试环境
- **Flutter 版本**: 3.38.3 (稳定版)
- **Dart 版本**: 3.10.1
- **运行环境**: Ubuntu Latest, macOS Latest, Windows Latest

### 缓存优化
- Flutter SDK 缓存
- Pub 依赖缓存
- 加快工作流执行速度

## 最佳实践

### 提交代码前
1. 运行 `flutter test` 确保所有测试通过
2. 运行 `flutter analyze` 检查代码质量
3. 修复所有测试失败和分析警告

### Pull Request 要求
- 所有测试必须通过 (test.yml 自动运行)
- 代码分析警告应最小化
- 新功能需要对应的测试覆盖

### 发布流程
1. 测试工作流在 PR 和推送时自动运行并验证
2. **手动触发**构建工作流 (build-all.yml / build-macos.yml / build-windows.yml)
3. 构建工作流中的测试再次验证
4. 测试通过后进行构建和发布

## 故障排除

### 常见测试失败原因
1. **依赖问题**: 运行 `flutter pub get` 更新依赖
2. **平台特定代码**: 确保测试跨平台兼容
3. **时间相关测试**: 检查时区和时间处理
4. **数据库测试**: 确保测试隔离和清理

### 调试测试失败
1. 查看 GitHub Actions 日志
2. 本地重现失败的测试
3. 使用 `flutter test --verbose` 获取详细信息
4. 检查测试环境差异

## 工作流触发方式总结

### 自动触发
- **test.yml**: 在 PR 和代码推送时自动运行
- 提供快速的测试反馈
- 确保代码质量门槛

### 手动触发
- **build-all.yml**: 完整的跨平台构建和发布
- **build-macos.yml**: 仅 macOS 构建和发布
- **build-windows.yml**: 仅 Windows 构建和发布
- 提供完全的发布控制权
- 确保构建过程的可控性

## 持续改进

测试工作流会持续优化，包括：
- 增加更多测试覆盖率
- 优化测试执行时间
- 添加性能测试
- 集成更多代码质量工具

记住：**测试是代码质量的保证，所有手动构建都要求测试完全通过！**
