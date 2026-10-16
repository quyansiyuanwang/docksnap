# Contributing

[English](CONTRIBUTING.md) | [简体中文](CONTRIBUTING.zh-CN.md)

## Development

```sh
swift build -Xswiftc -warnings-as-errors
swift test  -Xswiftc -warnings-as-errors
./build.sh                     # produces dist/DockSnap.app
```

Requirements: macOS 13 or later, Swift 6.0 or later, no Xcode project.

## Guidelines

- Keep the package free of third-party dependencies.
- Swift 6 language mode, strict concurrency, zero warnings. The build must pass
  with `-warnings-as-errors`.
- Add tests with Swift Testing (`@Suite` / `@Test` / `#expect`) for anything
  that is not a thin wrapper over a system API.
- Use the Accessibility API for window manipulation. Do not add private
  frameworks or require additional permissions.
- Follow the existing coordinate conventions: Accessibility space internally,
  Cocoa conversion only in `Screens.swift`.
- Commit messages: concise and conventional (`feat:`, `fix:`, `docs:`, ...).

## Pull requests

Describe the behaviour change and how it was verified. Include the output of
`swift build -Xswiftc -warnings-as-errors` and
`swift test -Xswiftc -warnings-as-errors`.
