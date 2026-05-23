#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SpyGlasses"
BUNDLE_ID="com.spyglasses.app"
APP_VERSION="${APP_VERSION:-0.1.0}"
APP_BUILD="${APP_BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-debug}"
INSTALL_APP="${INSTALL_APP:-1}"
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

ICON_SOURCE="$ROOT_DIR/assets/app-icon.svg"
ICON_VISIBLE_FRACTION="${ICON_VISIBLE_FRACTION:-0.82}"
ICONSET="$DIST_DIR/AppIcon.iconset"
ICON_SOURCE_PNG="$DIST_DIR/AppIconSource.png"
ICON_CANVAS_PNG="$DIST_DIR/AppIconCanvas.png"

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

build_binary() {
  swift build -c "$BUILD_CONFIGURATION"
  BUILD_BINARY="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)/$APP_NAME"
}

prepare_bundle() {
  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"
  cp "$BUILD_BINARY" "$APP_BINARY"
  chmod +x "$APP_BINARY"
}

compose_icon_canvas() {
  local visible_fraction="$1"
  local composer="$DIST_DIR/compose_icon.swift"

  cat >"$composer" <<'SWIFT'
import AppKit
import Foundation

let sourcePath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let visibleFraction = min(max(Double(CommandLine.arguments[3]) ?? 0.82, 0.1), 1.0)
let canvasSize = 1024.0

guard let source = NSImage(contentsOfFile: sourcePath) else {
  exit(1)
}

guard let tiff = source.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff)
else {
  exit(1)
}

var minX = bitmap.pixelsWide
var minY = bitmap.pixelsHigh
var maxX = -1
var maxY = -1

for y in 0..<bitmap.pixelsHigh {
  for x in 0..<bitmap.pixelsWide {
    if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.03 {
      minX = min(minX, x)
      minY = min(minY, y)
      maxX = max(maxX, x)
      maxY = max(maxY, y)
    }
  }
}

guard maxX >= minX, maxY >= minY else {
  exit(1)
}

let imageWidth = Double(bitmap.pixelsWide)
let imageHeight = Double(bitmap.pixelsHigh)
let contentMinX = Double(minX)
let contentMinY = Double(minY)
let contentWidth = Double(maxX - minX + 1)
let contentHeight = Double(maxY - minY + 1)
let targetSize = canvasSize * visibleFraction
let scale = min(targetSize / contentWidth, targetSize / contentHeight)
let drawWidth = imageWidth * scale
let drawHeight = imageHeight * scale
let drawX = (canvasSize - contentWidth * scale) / 2 - contentMinX * scale
let drawY = (canvasSize - contentHeight * scale) / 2 - contentMinY * scale
let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))

image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize).fill()
source.draw(
  in: NSRect(
    x: drawX,
    y: drawY,
    width: drawWidth,
    height: drawHeight
  ),
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

  swift "$composer" "$ICON_SOURCE_PNG" "$ICON_CANVAS_PNG" "$visible_fraction"
}

render_icon() {
  if [ ! -f "$ICON_SOURCE" ]; then
    echo "Missing app icon source: $ICON_SOURCE" >&2
    exit 1
  fi

  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"

  sips -s format png "$ICON_SOURCE" --out "$ICON_SOURCE_PNG" >/dev/null
  compose_icon_canvas "$ICON_VISIBLE_FRACTION"

  sips -z 16 16 "$ICON_CANVAS_PNG" --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_CANVAS_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_CANVAS_PNG" --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_CANVAS_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_CANVAS_PNG" --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_CANVAS_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_CANVAS_PNG" --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_CANVAS_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_CANVAS_PNG" --out "$ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_CANVAS_PNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET" -o "$APP_RESOURCES/AppIcon.icns"
}

write_info_plist() {
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
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
}

sign_bundle() {
  codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
  codesign --verify --deep --strict "$APP_BUNDLE"
}

install_bundle() {
  stop_running_app
  rm -rf "$APPLICATIONS_APP"
  ditto "$APP_BUNDLE" "$APPLICATIONS_APP"
  touch "$APPLICATIONS_APP"
  /usr/bin/open "$APPLICATIONS_APP"
}

cd "$ROOT_DIR"
build_binary
prepare_bundle
render_icon
write_info_plist
sign_bundle
if [ "$INSTALL_APP" = "1" ]; then
  install_bundle

  echo "$APPLICATIONS_APP"
else
  echo "$APP_BUNDLE"
fi
