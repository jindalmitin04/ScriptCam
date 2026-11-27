#!/bin/bash
set -euo pipefail

APP_NAME="ScriptCam"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
DMG_ROOT="$BUILD_DIR/dmg-root"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

command -v xcodegen >/dev/null 2>&1 || {
  echo "XcodeGen is required. Install it with: brew install xcodegen"
  exit 1
}

cd "$ROOT"
xcodegen generate
mkdir -p "$BUILD_DIR"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" CODE_SIGNING_ALLOWED=NO build

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"
cp -R "$APP_PATH" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH"
echo "Created: $DMG_PATH"
