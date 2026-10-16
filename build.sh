#!/usr/bin/env bash
# Build DockSnap.app into dist/ using the Swift toolchain only.
set -euo pipefail
cd "$(dirname "$0")"

CONFIGURATION=release
swift build -c "$CONFIGURATION" -Xswiftc -warnings-as-errors

BINARY=".build/$CONFIGURATION/DockSnap"
APP="dist/DockSnap.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$BINARY" "$APP/Contents/MacOS/DockSnap"
codesign --force --sign - --identifier com.quyansiyuanwang.docksnap "$APP"

echo "Built $APP"
