#!/bin/bash
# Builds the universal Release AudioNap.app (daemon embedded in
# Contents/Helpers), re-signs the nested code ad-hoc in explicit order, and
# verifies architectures, signature, the embedded daemon, and the
# release-critical plist keys.
# Usage: scripts/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED=build/DerivedData
PRODUCTS="$DERIVED/Build/Products/Release"
APP="$PRODUCTS/AudioNap.app"
APP_BIN="$APP/Contents/MacOS/AudioNap"
HELPER="$APP/Contents/Helpers/audionapd"
PLIST="$APP/Contents/Info.plist"

echo "==> Building AudioNap (Release, universal)"
xcodebuild -project AudioNap.xcodeproj -scheme AudioNap -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- build

echo "==> Re-signing nested code (helper first, then the app)"
codesign --force --sign - "$HELPER"
codesign --force --sign - "$APP"

echo "==> Verifying the embedded daemon"
[[ -x "$HELPER" ]] || { echo "ERROR: missing embedded daemon: $HELPER"; exit 1; }

echo "==> Verifying architectures"
for BIN in "$APP_BIN" "$HELPER"; do
  ARCHS_OUT=$(lipo -archs "$BIN")
  echo "    $BIN: $ARCHS_OUT"
  [[ "$ARCHS_OUT" == "x86_64 arm64" || "$ARCHS_OUT" == "arm64 x86_64" ]] \
    || { echo "ERROR: not universal: $BIN"; exit 1; }
done

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Verifying release-critical plist keys"
for key in CFBundleIconFile NSBluetoothAlwaysUsageDescription; do
  value=$(/usr/libexec/PlistBuddy -c "Print :$key" "$PLIST") \
    || { echo "ERROR: missing $key in the built Info.plist"; exit 1; }
  echo "    $key = $value"
done

echo "==> Versions"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST"
"$HELPER" --version
