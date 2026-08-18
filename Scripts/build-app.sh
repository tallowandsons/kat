#!/bin/sh
# Builds the Kat executable via SwiftPM and assembles it into a real .app bundle,
# since there's no Xcode project to do this for us.
#
# Usage: Scripts/build-app.sh [debug|release]

set -e

CONFIG="${1:-debug}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="com.tallowandsons.kat"
APP_NAME="Kat"
OUT_DIR="$ROOT_DIR/build"
APP_DIR="$OUT_DIR/$APP_NAME.app"

echo "==> swift build -c $CONFIG"
cd "$ROOT_DIR"
swift build -c "$CONFIG"

BIN_PATH="$ROOT_DIR/.build/$CONFIG/$APP_NAME"
if [ ! -f "$BIN_PATH" ]; then
    echo "error: built executable not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/CatFace.pdf" "$APP_DIR/Contents/Resources/CatFace.pdf"
cp "$ROOT_DIR/Resources/CatFull.pdf" "$APP_DIR/Contents/Resources/CatFull.pdf"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "==> codesigning with local 'Kat Dev' certificate (stable identifier: $BUNDLE_ID)"
# Plain ad-hoc signing (-s -) is silently ineligible for UNUserNotificationCenter
# authorization on modern macOS ("Notifications are not allowed for this application").
# A real local self-signed certificate (TeamIdentifier=not set is fine) is required
# instead; see the "No Xcode" risk in the plan for how this cert was created and
# imported into the login keychain.
codesign --force --deep --sign "Kat Dev" --identifier "$BUNDLE_ID" "$APP_DIR"

echo "==> done: $APP_DIR"
