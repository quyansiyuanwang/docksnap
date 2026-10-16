# DockSnap

A tiny macOS menu bar utility that remembers one window frame and puts it back
on demand, with the left edge aligned to the Dock.

Written in Swift. Builds with the Swift toolchain only — no Xcode project.

## Why

macOS window tiling and most window managers only offer fixed fractions. They
cannot save an arbitrary "current size and position". DockSnap records the
focused window's frame and restores it, so a layout such as *"left edge flush
with the Dock, top under the menu bar, right edge at the screen edge, bottom on
top of the Dock"* can be recalled from anywhere.

The alignment is dynamic: the Dock's icon strip geometry is read through the
Accessibility API on every restore, so the left edge stays correct when Dock
items are added or removed.

## Behaviour

- **保存当前窗口** records the focused window's `AXPosition` and `AXSize` into
  `~/Library/Application Support/DockSnap/frame.json`.
- **还原（左沿对齐程序坞）** ignores the recorded size: it fills the whole usable
  height from the Dock's current left edge to the screen's right edge, so both
  the top/bottom and the right edge reach the screen. The Dock geometry is read
  on every restore, so the left edge stays correct when Dock items change.
- **还原（精确）** reapplies the recorded frame exactly (still clamped on screen).

## Default shortcuts

| Action | Shortcut |
|---|---|
| Save the focused window | `⌃⌥⌘S` |
| Restore, left edge on the Dock | `⌃⌥⌘R` |
| Restore exactly | `⌃⌥⌘E` |

## Build

```sh
./build.sh                # produces dist/DockSnap.app
cp -R dist/DockSnap.app ~/Applications/
open ~/Applications/DockSnap.app
```

## Accessibility permission

Moving another app's window requires the Accessibility permission. On first
launch, add **DockSnap.app** under **System Settings → Privacy & Security →
Accessibility**.

The build signs with a local, self-signed identity (`DockSnap Local Signing`) so
the permission survives rebuilds. Create it once:

```sh
./scripts/create-signing-identity.sh
```

If that identity is missing, `build.sh` falls back to an ad-hoc signature; an
ad-hoc code hash changes on every build, so macOS drops the permission after each
rebuild.

## Command line

The same binary can be driven headlessly, which is useful for testing:

```sh
DockSnap.app/Contents/MacOS/DockSnap status
DockSnap.app/Contents/MacOS/DockSnap save
DockSnap.app/Contents/MacOS/DockSnap restore
DockSnap.app/Contents/MacOS/DockSnap restore-exact
DockSnap.app/Contents/MacOS/DockSnap show
```
