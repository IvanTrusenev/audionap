#!/bin/bash
# Builds and packages a release: asserts the requested version matches the
# app bundle, the daemon CLI, and AppIdentity, then produces dist/ zips
# and SHA256SUMS.txt.
# Usage: scripts/release.sh 0.1.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/release.sh <version> (e.g. 0.1.0)}"

./scripts/build.sh

PRODUCTS=build/DerivedData/Build/Products/Release
APP="$PRODUCTS/AudioNap.app"
HELPER="$APP/Contents/Helpers/audionapd"
DIST="$(pwd)/dist"

echo "==> Asserting version consistency with $VERSION"
grep -Fq "static let version = \"$VERSION\"" \
  Shared/Sources/Shared/Support/AppIdentity.swift \
  || { echo "ERROR: AppIdentity.version is not $VERSION"; exit 1; }

APP_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
DAEMON_VERSION=$("$HELPER" --version)
[[ "$APP_VERSION" == "$VERSION" ]] || { echo "ERROR: app version $APP_VERSION != $VERSION"; exit 1; }
[[ "$DAEMON_VERSION" == "$VERSION" ]] || { echo "ERROR: daemon version $DAEMON_VERSION != $VERSION"; exit 1; }

echo "==> Packaging"
rm -rf dist
mkdir -p dist
# ditto, not zip: preserves symlinks, the executable bit, and xattrs that
# an Info-ZIP archive would silently drop from the bundle.
(cd "$PRODUCTS" && ditto -c -k --keepParent AudioNap.app "$DIST/AudioNap-$VERSION.zip")
# No --keepParent here: for a file it would embed the parent directory
# (Release/audionapd); the cask and manual installs expect a bare root entry.
(cd "$PRODUCTS" && ditto -c -k audionapd "$DIST/audionapd-$VERSION.zip")
(cd dist && shasum -a 256 "AudioNap-$VERSION.zip" "audionapd-$VERSION.zip" > SHA256SUMS.txt)

ls -l dist
cat dist/SHA256SUMS.txt
echo "Upload the two zips and SHA256SUMS.txt to the v$VERSION GitHub release."
