#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SpyGlasses"
BUNDLE_ID="com.spyglasses.app"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APPLICATIONS_APP="/Applications/$APP_NAME.app"
ICON_SOURCE="$ROOT_DIR/Sources/SpyGlasses/Assets.xcassets/AppIcon.appiconset/UniversalAppIcon.png"
ICON_COMPOSER_DIR="$ROOT_DIR/Sources/SpyGlasses/spyglasses.icon"
ICON_COMPOSER_SOURCE="$ROOT_DIR/Sources/SpyGlasses/spyglasses.icon/Assets/network 2.svg"
ICON_COMPOSER_JSON="$ROOT_DIR/Sources/SpyGlasses/spyglasses.icon/icon.json"
ICONSET="$DIST_DIR/AppIcon.iconset"
ICON_RENDER_SOURCE="$DIST_DIR/AppIconSource.png"

if [ -f "$ICON_COMPOSER_SOURCE" ]; then
  ICON_SOURCE="$ICON_COMPOSER_SOURCE"
fi

stop_running_app() {
  /usr/bin/osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true

  for _ in {1..20}; do
    if ! pgrep -x "$APP_NAME" >/dev/null; then
      return
    fi

    sleep 0.1
  done

  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

cd "$ROOT_DIR"

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [ -f "$ICON_SOURCE" ]; then
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  if [[ "$ICON_SOURCE" == *.svg ]]; then
    sips -s format png "$ICON_SOURCE" --out "$ICON_RENDER_SOURCE" >/dev/null
    if [ -f "$ICON_COMPOSER_JSON" ]; then
      ICON_SCALE="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["groups"][0]["layers"][0]["position-specializations"][0]["value"].get("scale", 1))' "$ICON_COMPOSER_JSON")"
      ICON_RENDER_SOURCE="$DIST_DIR/AppIconComposed.png"
      ICON_COMPOSER_SWIFT="$DIST_DIR/compose_icon.swift"
      cat >"$ICON_COMPOSER_SWIFT" <<'SWIFT'
import AppKit
import Foundation

let sourcePath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let scale = Double(CommandLine.arguments[3]) ?? 1
let canvasSize = 1024.0

guard let source = NSImage(contentsOfFile: sourcePath) else {
  exit(1)
}

let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize).fill()

let drawSize = canvasSize * scale
let origin = (canvasSize - drawSize) / 2
source.draw(
  in: NSRect(x: origin, y: origin, width: drawSize, height: drawSize),
  from: NSRect(origin: .zero, size: source.size),
  operation: .sourceOver,
  fraction: 1
)
image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiffData),
  let pngData = bitmap.representation(using: .png, properties: [:])
else {
  exit(1)
}

try pngData.write(to: URL(fileURLWithPath: outputPath))
SWIFT
      swift "$ICON_COMPOSER_SWIFT" "$DIST_DIR/AppIconSource.png" "$ICON_RENDER_SOURCE" "$ICON_SCALE"
    fi
  else
    ICON_RENDER_SOURCE="$ICON_SOURCE"
  fi

  sips -z 16 16 "$ICON_RENDER_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_RENDER_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_RENDER_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_RENDER_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_RENDER_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_RENDER_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_RENDER_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_RENDER_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_RENDER_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_RENDER_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET" -o "$APP_RESOURCES/AppIcon.icns"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

stop_running_app
rm -rf "$APPLICATIONS_APP"
cp -R "$APP_BUNDLE" "$APPLICATIONS_APP"
touch "$APPLICATIONS_APP"
/usr/bin/open "$APPLICATIONS_APP"

echo "$APPLICATIONS_APP"
