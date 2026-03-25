#!/bin/bash
# Build a DMG for Markly
# Usage: ./Tools/build_dmg.sh [path-to-Markly.app]
#
# If no path is given, it looks for Build/Markly.app (Xcode archive output).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Markly"

# Find the .app bundle
if [[ $# -ge 1 ]]; then
    APP_PATH="$1"
else
    # Default: look in common Xcode build/archive locations
    APP_PATH="$ROOT_DIR/Build/${APP_NAME}.app"
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: ${APP_PATH} not found."
    echo "Either pass the path to Markly.app or build it first in Xcode (Product > Archive)."
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
DMG_NAME="${APP_NAME}-${VERSION}"
DMG_PATH="$ROOT_DIR/Build/${DMG_NAME}.dmg"
STAGING_DIR="$ROOT_DIR/Build/dmg-staging"

echo "Building DMG for ${APP_NAME} v${VERSION}..."

# Clean up any previous staging
rm -rf "$STAGING_DIR"
rm -f "$DMG_PATH"
mkdir -p "$STAGING_DIR"

# Copy app into staging
cp -R "$APP_PATH" "$STAGING_DIR/"

# Create a symlink to /Applications for drag-install
ln -s /Applications "$STAGING_DIR/Applications"

# Create the DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

# Clean up staging
rm -rf "$STAGING_DIR"

echo ""
echo "DMG created: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"

# Reveal in Finder
open -R "$DMG_PATH"
