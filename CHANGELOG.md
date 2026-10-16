# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-16

### Added

- Menu bar app that saves the focused window's frame and restores it.
- Dock-aligned restore: the left edge follows the Dock's icon strip, the height
  fills the usable area, and the right edge reaches the screen edge.
- Exact restore of the recorded frame.
- Global hot keys `⌃⌥⌘S`, `⌃⌥⌘R` and `⌃⌥⌘E` via Carbon's `RegisterEventHotKey`.
- Headless CLI (`save`, `restore`, `restore-exact`, `show`, `status`).
- Local self-signed signing identity so the Accessibility permission survives
  rebuilds.
- Tests for screen clamping and frame persistence.

[0.1.0]: https://github.com/quyansiyuanwang/docksnap/releases/tag/v0.1.0
