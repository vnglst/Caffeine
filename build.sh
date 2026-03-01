#!/bin/bash

# Build script for Caffeine menu bar app

set -e

APP_NAME="Caffeine"
BUILD_DIR="build"
CONTENTS_DIR="$BUILD_DIR/$APP_NAME.app/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Building $APP_NAME..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Compile iconset to icns
echo "Compiling app icon..."
ICONSET_DIR=$(mktemp -d)
cp -r "Caffeine/Assets.xcassets/AppIcon.appiconset" "$ICONSET_DIR/AppIcon.iconset"
iconutil -c icns -o "$RESOURCES_DIR/AppIcon.icns" "$ICONSET_DIR/AppIcon.iconset"
rm -rf "$ICONSET_DIR"

# Compile the Swift code
echo "Compiling app..."
swiftc \
    -o "$MACOS_DIR/$APP_NAME" \
    -framework Cocoa \
    -framework IOKit \
    Caffeine/main.swift

# Copy Info.plist
cp Caffeine/Info.plist "$CONTENTS_DIR/"

echo ""
echo "✓ Build complete!"
echo ""
echo "App location: $BUILD_DIR/$APP_NAME.app"
echo ""
echo "To run:"
echo "  open $BUILD_DIR/$APP_NAME.app"
echo ""
echo "To install to Applications:"
echo "  cp -r $BUILD_DIR/$APP_NAME.app /Applications/"
