#!/bin/sh
# Builds the Kat executable via SwiftPM and assembles it into a real .app bundle,
# since there's no Xcode project to do this for us.
#
# Usage: Scripts/build-app.sh [debug|release]
# Env:   UNIVERSAL=1  → build a universal (arm64 + x86_64) binary (for release/CI)
#        CI=1         → skip local-machine-only steps (this script has none today,
#                       but keeps parity with the CI signing fallback below)

set -e

CONFIG="${1:-debug}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="com.tallowandsons.kat"
APP_NAME="Kat"
OUT_DIR="$ROOT_DIR/build"
APP_DIR="$OUT_DIR/$APP_NAME.app"

# Version from the latest git tag (e.g. v1.2.0 -> 1.2.0), fallback 0.1.0.
VERSION="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || true)"
VERSION="${VERSION:-0.1.0}"
VERSION="${VERSION#v}"

# "owner/repo" derived from the git remote, for the in-app update check (Preferences ->
# Check for Updates) to know where to look on GitHub. Left unset if there's no
# GitHub-shaped remote, which silently disables the check.
REMOTE="$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || true)"
GHREPO="$(printf '%s' "$REMOTE" | sed -E 's#^git@github.com:##; s#^https://github.com/##; s#\.git$##')"

cd "$ROOT_DIR"

if [ "${UNIVERSAL:-0}" = "1" ]; then
    # `swift build --arch arm64 --arch x86_64` (both at once) routes through XCBuild,
    # which needs a full Xcode install -- not available under Command Line Tools alone
    # (confirmed failing locally: "xcbuild executable ... does not exist"). Building each
    # arch separately with a single --arch flag stays on plain SwiftPM the whole way, then
    # `lipo` glues the two slices together -- works with CLT only, on this Mac or CI alike.
    echo "==> swift build -c $CONFIG --arch arm64"
    swift build -c "$CONFIG" --arch arm64
    echo "==> swift build -c $CONFIG --arch x86_64"
    swift build -c "$CONFIG" --arch x86_64

    ARM_BIN="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIG/$APP_NAME"
    X86_BIN="$ROOT_DIR/.build/x86_64-apple-macosx/$CONFIG/$APP_NAME"
    BIN_PATH="$ROOT_DIR/.build/$APP_NAME-universal"
    echo "==> lipo -create (universal arm64+x86_64)"
    lipo -create -output "$BIN_PATH" "$ARM_BIN" "$X86_BIN"
else
    echo "==> swift build -c $CONFIG ($(uname -m))"
    swift build -c "$CONFIG"
    BIN_PATH="$ROOT_DIR/.build/$CONFIG/$APP_NAME"
fi

if [ ! -f "$BIN_PATH" ]; then
    echo "error: built executable not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> assembling $APP_DIR (version $VERSION)"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/CatFace.pdf" "$APP_DIR/Contents/Resources/CatFace.pdf"
cp "$ROOT_DIR/Resources/CatFull.pdf" "$APP_DIR/Contents/Resources/CatFull.pdf"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP_DIR/Contents/Info.plist"

if printf '%s' "$GHREPO" | grep -qE '^[^/]+/[^/]+$'; then
    /usr/libexec/PlistBuddy -c "Add :GHRepo string $GHREPO" "$APP_DIR/Contents/Info.plist"
fi

# Plain ad-hoc signing (-s -) is silently ineligible for UNUserNotificationCenter
# authorization on modern macOS ("Notifications are not allowed for this application").
# A real local self-signed certificate (TeamIdentifier=not set is fine) sidesteps that;
# see the "No Xcode" risk in the plan for how this cert was created and imported into
# the login keychain. That cert only exists on this Mac, though, so CI (and anyone else
# building this repo) falls back to ad-hoc — which means a CI-built release .zip won't
# be able to get notification permission on the machine that runs it. Known limitation,
# not something this script can fix without a real Developer ID.
SIGN_ID="Kat Dev"
if security find-identity -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
    echo "==> codesigning with local '$SIGN_ID' certificate (stable identifier: $BUNDLE_ID)"
    codesign --force --deep --sign "$SIGN_ID" --identifier "$BUNDLE_ID" "$APP_DIR"
else
    echo "==> '$SIGN_ID' certificate not found — falling back to ad-hoc signing"
    codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_DIR"
fi

echo "==> done: $APP_DIR (v$VERSION)"
