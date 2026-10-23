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

## Changelog

Do not edit `CHANGELOG.md` or `CHANGELOG.zh-CN.md`. Both files are generated at
release time from the conventional commit messages between two tags:

```sh
python3 scripts/changelog.py --tag v0.2.0 --write --notes-out release-notes.md
```

The release workflow runs the same script, commits the result to `main`, and
uses the generated notes for the GitHub release. Commit messages therefore drive
the changelog: `feat:` becomes *Added*, `fix:` *Fixed*, and `perf:`, `refactor:`
or `revert:` *Changed*. `docs:`, `ci:`, `build:`, `test:`, `style:` and `chore:`
commits produce no entry unless they change user-visible behaviour.

## Pull requests

Describe the behaviour change and how it was verified. Include the output of
`swift build -Xswiftc -warnings-as-errors` and
`swift test -Xswiftc -warnings-as-errors`.
