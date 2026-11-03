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

## 更新日志

请勿手动编辑 `CHANGELOG.md` 与 `CHANGELOG.zh-CN.md`。两个文件在发布时根据相邻
两个 tag 之间的约定式提交信息生成：

```sh
python3 scripts/changelog.py --tag v0.2.0 --write --notes-out release-notes.md
```

发布工作流会运行同一脚本，将结果提交到 `main`，并用生成的说明作为 GitHub Release
正文。因此提交信息决定了更新日志内容：`feat:` 归入“新增”，`fix:` 归入“修复”，
`perf:`、`refactor:`、`revert:` 归入“改进”。`docs:`、`ci:`、`build:`、`test:`、
`style:`、`chore:` 不会产生条目，除非它们改变了用户可见行为。

## 拉取请求

请说明行为变更以及验证方式，并附上以下命令的输出：

```sh
swift build -Xswiftc -warnings-as-errors
swift test  -Xswiftc -warnings-as-errors
```
