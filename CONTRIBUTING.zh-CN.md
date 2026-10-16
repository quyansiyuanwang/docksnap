# 贡献指南

[English](CONTRIBUTING.md) | 简体中文

## 开发

```sh
swift build -Xswiftc -warnings-as-errors
swift test  -Xswiftc -warnings-as-errors
./build.sh                     # 产出 dist/DockSnap.app
```

环境要求：macOS 13 或更高，Swift 6.0 或更高，不需要 Xcode 工程。

## 约定

- 保持包内无第三方依赖。
- Swift 6 语言模式、严格并发、零警告。构建必须在 `-warnings-as-errors`
  下通过。
- 对任何不是"系统 API 薄封装"的逻辑，都用 Swift Testing
  （`@Suite` / `@Test` / `#expect`）补测试。
- 窗口操作一律使用辅助功能接口。不要引入私有框架，也不要要求额外权限。
- 遵循既有的坐标约定：内部使用辅助功能坐标（左上原点、y 向下），仅在
  `Screens.swift` 中做 Cocoa 转换。
- 提交信息：简洁，遵循约定式提交（`feat:`、`fix:`、`docs:` 等）。

## 拉取请求

请说明行为变更以及验证方式，并附上以下命令的输出：

```sh
swift build -Xswiftc -warnings-as-errors
swift test  -Xswiftc -warnings-as-errors
```
