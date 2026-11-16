#!/bin/bash
# Perch.app paketini üretir: ./Scripts/build_app.sh
# Sürüm değiştirmek için: VERSION=1.1.0 ./Scripts/build_app.sh
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.1.0}"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Perch"

APP="build/Perch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Perch"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Perch</string>
  <key>CFBundleDisplayName</key><string>Perch</string>
  <key>CFBundleIdentifier</key><string>dev.perch.app</string>
  <key>CFBundleExecutable</key><string>Perch</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Çentikte çalan şarkıyı göstermek, müziği kontrol etmek ve sesli notları Notlar'a kaydetmek için Spotify, Music ve Notlar ile konuşmam gerekiyor. / Needed to show and control Spotify/Music playback and to save voice notes to Notes.</string>
  <key>NSBluetoothAlwaysUsageDescription</key>
  <string>Away Guard (beta): iPhone / Apple Watch'unun sinyal gücüne bakarak yanından ayrıldığını anlamak için Bluetooth'u kullanıyorum. / Away Guard (beta): uses Bluetooth signal strength of your iPhone / Apple Watch to know when you step away.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Sesli not kaydetmek için mikrofona erişmem gerekiyor. / Needed to record voice notes.</string>
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>Sesli notları cihaz üzerinde yazıya çevirmek için konuşma tanımayı kullanıyorum. / Used to transcribe voice notes on-device.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Hazır: $APP (v${VERSION})"
