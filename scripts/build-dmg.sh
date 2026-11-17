#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Mustang Studio.app"
STAGE="$BUILD/dmg"
DESKTOP_DMG="${MUSTANG_DMG_PATH:-$HOME/Desktop/MustangStudio.dmg}"
SDK="$(xcrun --show-sdk-path)"

rm -rf "$APP" "$STAGE"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD/icon.iconset"

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

python3 "$ROOT/scripts/make_icon.py" "$BUILD/icon-1024.png"
sips -z 16 16 "$BUILD/icon-1024.png" --out "$BUILD/icon.iconset/icon_16x16.png" >/dev/null
sips -z 32 32 "$BUILD/icon-1024.png" --out "$BUILD/icon.iconset/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$BUILD/icon-1024.png" --out "$BUILD/icon.iconset/icon_32x32.png" >/dev/null
sips -z 64 64 "$BUILD/icon-1024.png" --out "$BUILD/icon.iconset/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$BUILD/icon-1024.png" --out "$BUILD/icon.iconset/icon_128x128.png" >/dev/null
sips -z 256 256 "$BUILD/icon-1024.png" --out "$BUILD/icon.iconset/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$BUILD/icon-1024.png" --out "$BUILD/icon.iconset/icon_256x256.png" >/dev/null
sips -z 512 512 "$BUILD/icon-1024.png" --out "$BUILD/icon.iconset/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$BUILD/icon-1024.png" --out "$BUILD/icon.iconset/icon_512x512.png" >/dev/null
cp "$BUILD/icon-1024.png" "$BUILD/icon.iconset/icon_512x512@2x.png"
iconutil -c icns "$BUILD/icon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

swiftc \
  -parse-as-library \
  -swift-version 5 \
  -O \
  -sdk "$SDK" \
  -target arm64-apple-macosx14.0 \
  -framework SwiftUI \
  -framework AppKit \
  -framework AVFAudio \
  -framework AVFoundation \
  -framework CoreAudio \
  -framework AudioToolbox \
  -o "$APP/Contents/MacOS/MustangStudio" \
  "$ROOT"/Sources/*.swift

codesign --force --sign - --identifier com.lucacampo.mustangstudio "$APP"

mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Mustang Studio.app"
cp "$ROOT/packaging/LEGGIMI.txt" "$STAGE/LEGGIMI.txt"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "Mustang Studio" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DESKTOP_DMG"

echo "DMG pronto: $DESKTOP_DMG"
