# DockSnap

[![CI](https://github.com/quyansiyuanwang/docksnap/actions/workflows/ci.yml/badge.svg)](https://github.com/quyansiyuanwang/docksnap/actions/workflows/ci.yml)

A tiny macOS menu bar utility that remembers window frames and puts them back,
with the left edge aligned to the Dock.

Written in Swift. Builds with the Swift toolchain only — no Xcode project, no
third-party dependencies.

## Why

macOS window tiling and most window managers only offer fixed fractions: halves,
thirds, quarters. They cannot save an arbitrary *current size and position*.

DockSnap records the focused window's frame and restores it. The layout that
motivated it is *"left edge flush with the Dock, top under the menu bar, right
edge at the screen edge, bottom on top of the Dock"* — a shape no built-in
layout produces, and one that has to track the Dock when its item count changes.

## Features

- Save the focused window's `AXPosition` and `AXSize`.
- Restore it with the left edge aligned to the Dock's icon strip, filling the
  full usable height and the width up to the right screen edge.
- Restore the recorded frame exactly.
- The Dock's geometry is read on every restore, so the layout stays correct when
  Dock items are added or removed, or when the Dock moves.
- Global hot keys that do not need extra permissions of their own.
- A headless CLI for scripting and testing.

## Requirements

| | |
| --- | --- |
| macOS | 13 or later (developed on macOS 15) |
| Swift | 6.0+ (`swift-tools-version: 6.0`) |
| Dependencies | none |

## Install

### Download

Download `DockSnap-<version>.zip` from the
[releases](https://github.com/quyansiyuanwang/docksnap/releases) page, move
`DockSnap.app` to `/Applications` (or `~/Applications`), then clear the
quarantine attribute. Release builds are signed ad-hoc and are not notarized,
so Gatekeeper blocks the first launch otherwise.

```sh
xattr -dr com.apple.quarantine /Applications/DockSnap.app
open /Applications/DockSnap.app
```

### Build from source

```sh
git clone https://github.com/quyansiyuanwang/docksnap.git
cd docksnap
./scripts/create-signing-identity.sh   # optional, see below
./build.sh
cp -R dist/DockSnap.app /Applications/   # or ~/Applications/
open /Applications/DockSnap.app
```

### Accessibility permission

Moving another application's window requires the Accessibility permission. On
first launch, add **DockSnap.app** under **System Settings → Privacy & Security
→ Accessibility**.

macOS ties that permission to the app's code signature. An ad-hoc signature
(`codesign -s -`) has a code hash that changes on every build, so the permission
is dropped each time. `scripts/create-signing-identity.sh` creates a local,
self-signed certificate (`DockSnap Local Signing`) whose designated requirement
is stable across rebuilds:

```text
identifier "com.quyansiyuanwang.docksnap" and certificate leaf = H"..."
```

The certificate never leaves the machine. Remove it with:

```sh
security delete-identity -c "DockSnap Local Signing"
```

Without it, `build.sh` falls back to an ad-hoc signature and macOS will ask for
the permission again after every rebuild.

## Usage

### Global hot keys

| Action | Shortcut |
| --- | --- |
| Save the focused window | `⌃⌥⌘S` |
| Restore, left edge on the Dock | `⌃⌥⌘R` |
| Restore exactly | `⌃⌥⌘E` |

Change them in `Sources/DockSnap/AppDelegate.swift` (the `kVK_ANSI_*` constants).

### Menu bar

The status item exposes the same commands plus *Show saved window* and
*Accessibility settings*.

### Command line

```sh
DockSnap.app/Contents/MacOS/DockSnap save
DockSnap.app/Contents/MacOS/DockSnap restore
DockSnap.app/Contents/MacOS/DockSnap restore-exact
DockSnap.app/Contents/MacOS/DockSnap show
DockSnap.app/Contents/MacOS/DockSnap status
```

## How it works

Everything is built on the Accessibility API, so no screen recording permission
and no private frameworks are involved.

- The focused window is found through `AXUIElementCreateApplication` +
  `kAXFocusedWindow`, and moved with `AXPosition` / `AXSize`.
- The Dock's icon strip is an `AXList` exposed by the Dock process. Its frame
  gives the left edge and the top edge of the Dock.
- `NSScreen.visibleFrame` gives the usable area (menu bar and Dock excluded).
- The dock-aligned restore combines them: `x` from the Dock, `y` and `height`
  from the visible frame, and `width` from the Dock's left edge to the screen's
  right edge. The result is clamped on screen.

Coordinates are converted between Cocoa's bottom-left origin and the
Accessibility API's top-left origin in `Screens.swift`.

## Limitations

- One frame is remembered, not a set of named layouts.
- The action always applies to the frontmost window.
- Some applications snap their window size to a grid (terminals snap to
  character cells), so the right or bottom edge can be a few pixels short of the
  screen. DockSnap requests the full area; the application decides the rest.
- Global hot keys use Carbon's `RegisterEventHotKey`. They work without the
  Accessibility permission, which is only needed to move windows.

## Development

```sh
swift build -Xswiftc -warnings-as-errors
swift test  -Xswiftc -warnings-as-errors
./build.sh
```

The source layout:

| Path | Purpose |
| --- | --- |
| `Sources/DockSnap/DockSnapMain.swift` | Entry point; GUI or headless CLI |
| `Sources/DockSnap/AppDelegate.swift` | Status item and menu |
| `Sources/DockSnap/HotKeys.swift` | Carbon global hot keys |
| `Sources/DockSnap/WindowLayout.swift` | Save / restore behaviour |
| `Sources/DockSnap/AX.swift` | Accessibility wrappers |
| `Sources/DockSnap/DockGeometry.swift` | Dock icon-strip frame |
| `Sources/DockSnap/Screens.swift` | Coordinate conversion and clamping |
| `Sources/DockSnap/FrameStore.swift` | Persisted frame |
| `Sources/DockSnap/CLI.swift` | Headless commands |

## License

MIT. See [LICENSE](LICENSE).
