#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ClipX"
BUNDLE_ID="com.clipx.app"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "=== 1. 编译 ==="
cd "$PROJECT_DIR"
swift build -c release

echo ""
echo "=== 2. 打包 $APP_NAME.app ==="
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$PROJECT_DIR/.build/release/ClipboardHistory" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Info.plist（必须在 icns 之前复制）
cp "$PROJECT_DIR/ClipboardHistory/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null

# 生成 icns 图标
echo "生成图标..."
ICON_PNG="$PROJECT_DIR/ClipboardHistory/Assets.xcassets/AppIcon.appiconset/appicon.png"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET_DIR" && mkdir -p "$ICONSET_DIR"

SIZES=(16 32 64 128 256 512)
for s in "${SIZES[@]}"; do
    s2=$((s * 2))
    sips -z $s  $s  "$ICON_PNG" --out "$ICONSET_DIR/icon_${s}x${s}.png" &>/dev/null
    sips -z $s2 $s2 "$ICON_PNG" --out "$ICONSET_DIR/icon_${s}x${s}@2x.png" &>/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null
rm -rf "$ICONSET_DIR"

# 写入图标引用
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null

# 签名
echo "签名..."
# 设置图标
swift "$PROJECT_DIR/scripts/set_icon.swift" "$APP_BUNDLE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null && echo "图标已设置" || true

echo "签名..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null && echo "已签名" || true

# 创建 DMG
echo ""
echo "=== 3. 创建 DMG ==="
DMG_DIR="$BUILD_DIR/dmg"
DMG_FILE="$BUILD_DIR/$APP_NAME.dmg"
rm -rf "$DMG_DIR" "$DMG_FILE"
mkdir -p "$DMG_DIR"
cp -R "$APP_BUNDLE" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_FILE" 2>/dev/null
rm -rf "$DMG_DIR"

echo ""
echo "=== ✅ 完成 ==="
echo "DMG: $DMG_FILE"
open -R "$DMG_FILE"
