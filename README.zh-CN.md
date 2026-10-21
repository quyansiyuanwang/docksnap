# DockSnap

[![CI](https://github.com/quyansiyuanwang/docksnap/actions/workflows/ci.yml/badge.svg)](https://github.com/quyansiyuanwang/docksnap/actions/workflows/ci.yml)

[English](README.md) | 简体中文

一个 macOS 菜单栏小工具：记录窗口的位置与大小，并在需要时还原，使窗口左沿与程序坞对齐。

使用 Swift 编写，仅依赖 Swift 工具链即可构建——不需要 Xcode 工程，不引入任何第三方依赖。

## 背景

macOS 自带的窗口平铺以及大多数窗口管理器只提供固定比例：一半、三分之一、四分之一。它们无法保存任意一个"当前的大小与位置"。

DockSnap 记录当前焦点窗口的边框并可将其还原。促使这个工具诞生的布局是：**左沿与程序坞齐平、上方贴住菜单栏、右侧顶到屏幕边缘、下方坐在程序坞之上**——这是任何内置布局都产生不了的形状，而且必须随程序坞图标数量的变化而跟随。

## 功能

- 记录当前焦点窗口的 `AXPosition` 与 `AXSize`。
- 还原时左沿与程序坞图标栏对齐，纵向铺满可用高度，横向一直延伸到屏幕右沿。
- 也可以按记录的边框精确还原。
- 还原前退出 macOS 全屏状态，使位于全屏空间的窗口重新可移动、可调整大小。
- 每次写入后读回实际边框校验，只重试仍未生效的属性。
- 每次还原都重新读取程序坞的几何信息，因此增删程序坞图标、移动程序坞后布局依然正确。
- 全局快捷键本身不需要额外权限。
- 提供无界面的命令行接口，便于脚本化与测试。

## 环境要求

| | |
| --- | --- |
| macOS | 13 或更高（在 macOS 15 上开发，在 macOS 27 上验证） |
| Swift | 6.0+（`swift-tools-version: 6.0`） |
| 依赖 | 无 |

## 安装

### 下载

从 [releases](https://github.com/quyansiyuanwang/docksnap/releases) 页面下载 `DockSnap-<version>.zip`，把 `DockSnap.app` 移动到 `/Applications`（或 `~/Applications`），然后清除隔离属性。发布包是 ad-hoc 签名且未做公证，不清除的话 Gatekeeper 会阻止首次启动。

```sh
xattr -dr com.apple.quarantine /Applications/DockSnap.app
open /Applications/DockSnap.app
```

### 从源码构建

```sh
git clone https://github.com/quyansiyuanwang/docksnap.git
cd docksnap
./scripts/create-signing-identity.sh   # 可选，见下文
./build.sh
cp -R dist/DockSnap.app /Applications/   # 或 ~/Applications/
open /Applications/DockSnap.app
```

### 辅助功能权限

移动其它应用的窗口需要"辅助功能"权限。首次启动后，在 **系统设置 → 隐私与安全性 → 辅助功能** 中添加 **DockSnap.app**。

macOS 会把该权限与应用代码签名绑定。ad-hoc 签名（`codesign -s -`）的代码哈希每次构建都会变化，因此权限每次构建后都会失效。`scripts/create-signing-identity.sh` 会在本机创建一个自签名证书（`DockSnap Local Signing`），其指定要求是稳定的，重建后不变：

```text
identifier "com.quyansiyuanwang.docksnap" and certificate leaf = H"..."
```

该证书不会离开本机。如需删除：

```sh
security delete-identity -c "DockSnap Local Signing"
```

若不存在该身份，`build.sh` 会回退到 ad-hoc 签名，此时每次重建后 macOS 都会重新要求授权。

## 用法

### 全局快捷键

| 操作 | 快捷键 |
| --- | --- |
| 保存当前窗口 | `⌃⌥⌘S` |
| 还原（左沿对齐程序坞） | `⌃⌥⌘R` |
| 精确还原 | `⌃⌥⌘E` |

可在 `Sources/DockSnap/AppDelegate.swift` 中修改（`kVK_ANSI_*` 常量）。

### 菜单栏

状态栏菜单提供同样的命令，另有"查看已保存的窗口"与"辅助功能设置"。

### 命令行

```sh
DockSnap.app/Contents/MacOS/DockSnap save
DockSnap.app/Contents/MacOS/DockSnap restore
DockSnap.app/Contents/MacOS/DockSnap restore-exact
DockSnap.app/Contents/MacOS/DockSnap show
DockSnap.app/Contents/MacOS/DockSnap status
```

## 工作原理

全部基于辅助功能（Accessibility）接口，不涉及屏幕录制权限，也不使用私有框架。

- 通过 `AXUIElementCreateApplication` 加 `kAXFocusedWindow` 找到焦点窗口，再用 `AXPosition` / `AXSize` 移动它。
- 程序坞的图标栏是 Dock 进程暴露的一个 `AXList`，其边框给出程序坞的左沿与顶沿。
- `NSScreen.visibleFrame` 给出可用区域（已排除菜单栏与程序坞）。
- "左沿对齐程序坞"的还原把两者组合起来：`x` 取自程序坞，`y` 与 `height` 取自可见区域，`width` 从程序坞左沿延伸到屏幕右沿，最后再做屏幕内钳制。

写入边框前，若窗口报告 `AXFullScreen`，会先让其退出全屏：全屏窗口会拒绝位置写入并忽略尺寸写入。写入顺序固定为先 `AXPosition` 后 `AXSize`，因为部分应用在收到后置的位置写入时会撤销尺寸调整。随后读回实际边框，只对仍有差异的属性进行纠正。

坐标在 Cocoa 的左下原点与辅助功能接口的左上原点之间转换，逻辑集中在 `Screens.swift`。

## 限制

- 只记忆一个窗口边框，不是一组具名布局。
- 操作对象始终是最前方的窗口。
- 还原全屏窗口前会先退出全屏空间。
- 部分应用会把窗口尺寸对齐到网格（终端会对齐到字符单元格），因此右沿或下沿可能比屏幕边缘差几个像素。DockSnap 请求的是完整区域；若尺寸发生了变化但未达到请求值，则接受应用最终决定的尺寸；若尺寸完全没有变化，则报告失败。
- 全局快捷键使用 Carbon 的 `RegisterEventHotKey`，本身不需要辅助功能权限；该权限只在移动窗口时才需要。

## 开发

```sh
swift build -Xswiftc -warnings-as-errors
swift test  -Xswiftc -warnings-as-errors
./build.sh
```

源码结构：

| 路径 | 职责 |
| --- | --- |
| `Sources/DockSnap/DockSnapMain.swift` | 入口；图形界面或无界面命令行 |
| `Sources/DockSnap/AppDelegate.swift` | 状态栏项目与菜单 |
| `Sources/DockSnap/HotKeys.swift` | Carbon 全局快捷键 |
| `Sources/DockSnap/WindowLayout.swift` | 保存 / 还原逻辑 |
| `Sources/DockSnap/AX.swift` | 辅助功能接口封装 |
| `Sources/DockSnap/FramePlan.swift` | 到达目标边框所需的属性写入 |
| `Sources/DockSnap/DockGeometry.swift` | 程序坞图标栏边框 |
| `Sources/DockSnap/Screens.swift` | 坐标转换与钳制 |
| `Sources/DockSnap/FrameStore.swift` | 边框持久化 |
| `Sources/DockSnap/CLI.swift` | 无界面命令 |

约定与拉取请求检查项见 [CONTRIBUTING.zh-CN.md](CONTRIBUTING.zh-CN.md)。

## 许可证

MIT，见 [LICENSE](LICENSE)。
