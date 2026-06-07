#!/bin/bash
set -e

echo "=== Building Easy Agent (Release) ==="
swift build -c release

echo "=== Preparing EasyAgent.app Bundle ==="
APP_PATH="/Users/junxibao/Desktop/EasyAgent.app"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

echo "=== Copying Binary and Info.plist ==="
cp .build/release/EasyAgent "$APP_PATH/Contents/MacOS/EasyAgent"
cp Info.plist "$APP_PATH/Contents/Info.plist"

echo "=== Copying Resource Bundles ==="
if [ -d ".build/release/Highlightr_Highlightr.bundle" ]; then
    cp -R ".build/release/Highlightr_Highlightr.bundle" "$APP_PATH/Contents/Resources/"
fi

echo "=== Generating App Icon (.icns) ==="
ICON_RAW=$(find AppIcon.iconset -type f -not -name '.*' | head -n 1)
ICON_PNG="icon_converted.png"
sips -s format png "$ICON_RAW" --out "$ICON_PNG" > /dev/null 2>&1

TEMP_ICONSET="TempIcon.iconset"
rm -rf "$TEMP_ICONSET"
mkdir -p "$TEMP_ICONSET"

# Resize icons using sips
sips -z 16 16 "$ICON_PNG" --out "$TEMP_ICONSET/icon_16x16.png" > /dev/null 2>&1
sips -z 32 32 "$ICON_PNG" --out "$TEMP_ICONSET/icon_16x16@2x.png" > /dev/null 2>&1
sips -z 32 32 "$ICON_PNG" --out "$TEMP_ICONSET/icon_32x32.png" > /dev/null 2>&1
sips -z 64 64 "$ICON_PNG" --out "$TEMP_ICONSET/icon_32x32@2x.png" > /dev/null 2>&1
sips -z 128 128 "$ICON_PNG" --out "$TEMP_ICONSET/icon_128x128.png" > /dev/null 2>&1
sips -z 256 256 "$ICON_PNG" --out "$TEMP_ICONSET/icon_128x128@2x.png" > /dev/null 2>&1
sips -z 256 256 "$ICON_PNG" --out "$TEMP_ICONSET/icon_256x256.png" > /dev/null 2>&1
sips -z 512 512 "$ICON_PNG" --out "$TEMP_ICONSET/icon_256x256@2x.png" > /dev/null 2>&1
sips -z 512 512 "$ICON_PNG" --out "$TEMP_ICONSET/icon_512x512.png" > /dev/null 2>&1
sips -z 1024 1024 "$ICON_PNG" --out "$TEMP_ICONSET/icon_512x512@2x.png" > /dev/null 2>&1

# Compile to .icns
iconutil -c icns "$TEMP_ICONSET" -o "$APP_PATH/Contents/Resources/AppIcon.icns"
rm -rf "$TEMP_ICONSET"
rm -f "$ICON_PNG"

# Code sign the app bundle (essential for macOS to register resources and run properly)
echo "=== Signing EasyAgent.app ==="
codesign --force --deep --sign - "$APP_PATH"

# Force register with LaunchServices and notify Finder
echo "=== Refreshing System Icon Cache ==="
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_PATH"
touch "$APP_PATH"

echo "=== Packaging DMG ==="
DMG_TEMP="/Users/junxibao/Desktop/EasyAgent_DMG_Temp"
DMG_PATH="/Users/junxibao/Desktop/EasyAgent.dmg"

echo "Preparing packaging directory..."
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"
cp -R "$APP_PATH" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

echo "Creating disk image..."
rm -f "$DMG_PATH"
hdiutil create -volname "EasyAgent" -srcfolder "$DMG_TEMP" -ov -format UDZO "$DMG_PATH"

echo "Cleaning up temporary files..."
rm -rf "$DMG_TEMP"

echo "=== Build and Packaging Complete! ==="
echo "Easy Agent App: $APP_PATH"
echo "Easy Agent DMG: $DMG_PATH"
