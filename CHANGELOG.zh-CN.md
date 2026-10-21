# 更新日志

[English](CHANGELOG.md) | 简体中文

本项目的所有重要变更都记录在此文件。格式遵循
[Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循
[语义化版本](https://semver.org/lang/zh-CN/)。

## [未发布]

### 修复

- 修复 macOS 27 上无法还原全屏窗口的问题：写入边框前先退出全屏空间，因为全屏窗口会拒绝 `AXPosition` 并忽略 `AXSize`。
- 写入后读回实际边框，只重试仍有差异的属性，避免尾随的 `AXPosition` 写入在部分应用中撤销刚设置的尺寸。
- 应用完全忽略目标尺寸时报告失败；被网格或最小尺寸约束的尺寸仍视为应用最终决定。

## [0.1.0] - 2026-10-16

### 新增

- 菜单栏应用：记录当前焦点窗口的边框，并在需要时将其还原。
- 左沿对齐程序坞的还原：左沿跟随程序坞图标栏，纵向铺满可用高度，右沿顶到屏幕边缘。
- 按记录的边框精确还原。
- 通过 Carbon 的 `RegisterEventHotKey` 提供全局快捷键 `⌃⌥⌘S`、`⌃⌥⌘R`、`⌃⌥⌘E`。
- 无界面命令行接口（`save`、`restore`、`restore-exact`、`show`、`status`）。
- 本地自签名身份，使辅助功能权限在重建后保留。
- 屏幕钳制与边框持久化的测试。

[0.1.0]: https://github.com/quyansiyuanwang/docksnap/releases/tag/v0.1.0
