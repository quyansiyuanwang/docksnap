#!/usr/bin/env bash
# Build DockSnap.app into dist/ using the Swift toolchain only.
#
# Signs with a local, self-signed identity when present so that the
# Accessibility permission survives rebuilds (an ad-hoc signature changes its
# code hash on every build and gets re-prompted). Create the identity once with
# scripts/create-signing-identity.sh.
set -euo pipefail
cd "$(dirname "$0")"

CONFIGURATION=release
IDENTITY="DockSnap Local Signing"
BUNDLE_ID="com.quyansiyuanwang.docksnap"

swift build -c "$CONFIGURATION" -Xswiftc -warnings-as-errors

BINARY=".build/$CONFIGURATION/DockSnap"
APP="dist/DockSnap.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$BINARY" "$APP/Contents/MacOS/DockSnap"

if codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$APP" 2>/dev/null; then
    echo "Signed with \"$IDENTITY\""
else
    echo "Identity \"$IDENTITY\" not found; falling back to ad-hoc (permission is lost on rebuild)."
    codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
fi

echo "Built $APP"
