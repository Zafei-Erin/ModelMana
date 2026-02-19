#!/bin/bash

# Build script for creating a release DMG of ModelMana

set -e

BUILD_DIR="./build"
ARCHIVE_PATH="$BUILD_DIR/ModelMana.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_PATH="$BUILD_DIR/ModelMana.dmg"

echo "🔨 Building ModelMana..."
echo ""

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 1: Archive
echo "📦 Creating archive..."
xcodebuild archive \
  -project ModelMana.xcodeproj \
  -scheme ModelMana \
  -archivePath "$ARCHIVE_PATH" \
  CONFIGURATION=Release

# Step 2: Export
echo "📤 Exporting app..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist exportOptions.plist

# Step 3: Create DMG
echo "💿 Creating DMG..."
hdiutil create \
  -volname "ModelMana" \
  -srcfolder "$EXPORT_PATH" \
  -ov -format UDZO \
  "$DMG_PATH"

echo ""
echo "✅ Done! DMG created at: $DMG_PATH"
ls -lh "$DMG_PATH"
