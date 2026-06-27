#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-debug}"
APP="tab-switch.app"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"

swift build -c "$CONFIG"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_PATH/TabSwitchApp" "$APP/Contents/MacOS/tab-switch"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>tab-switch</string>
  <key>CFBundleIdentifier</key><string>local.tabswitch</string>
  <key>CFBundleExecutable</key><string>tab-switch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

echo "Built $APP"
