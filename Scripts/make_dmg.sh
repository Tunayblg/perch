#!/bin/bash
# Dağıtım için .dmg üretir: ./Scripts/make_dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.0.0}"

VERSION="$VERSION" ./Scripts/build_app.sh

STAGE="build/dmg"
DMG="build/Perch-${VERSION}.dmg"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R build/Perch.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "Perch" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "Hazır: $DMG"
