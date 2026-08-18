#!/bin/sh
# Builds KatSaver.saver, a macOS screensaver plugin, entirely outside SwiftPM's target
# system: SwiftPM's library product types don't cleanly produce the MH_BUNDLE-style
# Mach-O (`-bundle` linker mode) that NSBundle/ScreenSaverView loading expects, so this
# invokes swiftc directly, the same way build-app.sh works around not having Xcode.
#
# Usage: Scripts/build-saver.sh

set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT_DIR/Screensaver"
OUT_DIR="$ROOT_DIR/build"
SAVER_NAME="KatSaver"
SAVER_DIR="$OUT_DIR/$SAVER_NAME.saver"
BUNDLE_ID="com.tallowandsons.katsaver"

mkdir -p "$SAVER_DIR/Contents/MacOS"
mkdir -p "$SAVER_DIR/Contents/Resources"

echo "==> compiling $SAVER_NAME.saver binary"
# BreakStatus.swift is compiled from Kat.app's own source tree (not copied) so the two
# builds can never drift out of sync with each other's Codable shape.
swiftc \
    -module-name "$SAVER_NAME" \
    -emit-library \
    -Xlinker -bundle \
    -framework ScreenSaver \
    -framework AppKit \
    -framework Foundation \
    -o "$SAVER_DIR/Contents/MacOS/$SAVER_NAME" \
    "$SRC_DIR/KatSaverView.swift" \
    "$ROOT_DIR/Sources/Kat/Models/BreakStatus.swift"

cp "$SRC_DIR/Info.plist" "$SAVER_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/CatFull.pdf" "$SAVER_DIR/Contents/Resources/CatFull.pdf"

echo "==> codesigning with local 'Kat Dev' certificate"
codesign --force --deep --sign "Kat Dev" --identifier "$BUNDLE_ID" "$SAVER_DIR"

echo "==> done: $SAVER_DIR"
