#!/bin/sh
# Builds Kat and installs it to /Applications, replacing any existing copy there.
# Building always happens in ./build/Kat.app first — this script is a separate, explicit
# "publish" step for when you want the installed copy (needed for Launch at Login via
# SMAppService, which requires a real installed app rather than a dev build) to match
# what you've been testing locally.
#
# Usage: Scripts/install.sh [debug|release]

set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-debug}"

"$ROOT_DIR/Scripts/build-app.sh" "$CONFIG"

echo "==> installing to /Applications/Kat.app"
pkill -f "/Applications/Kat.app/Contents/MacOS/Kat" 2>/dev/null || true
rm -rf /Applications/Kat.app
cp -R "$ROOT_DIR/build/Kat.app" /Applications/Kat.app

echo "==> done: /Applications/Kat.app"
