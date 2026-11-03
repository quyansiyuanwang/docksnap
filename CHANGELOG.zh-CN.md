# 更新日志

[English](CHANGELOG.md) | 简体中文

本项目的所有重要变更都记录在此文件。格式遵循
[Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循
[语义化版本](https://semver.org/lang/zh-CN/)。

以下段落由发布工作流根据每个版本的约定式提交信息，通过
`scripts/changelog.py` 生成。请勿手动编辑本文件；`CHANGELOG.md` 在同一次运行中生成。

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
