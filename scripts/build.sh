#!/usr/bin/env bash
set -e

echo "=== Building AmpNotch for macOS ==="

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

mkdir -p build
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/AmpNotch.app"

echo "[1/4] Compiling Swift sources..."
swiftc -parse-as-library -O -target "$(uname -m)-apple-macos13.0" \
    Sources/Models/*.swift \
    Sources/Services/*.swift \
    Sources/Views/Components/*.swift \
    Sources/Views/Notch/*.swift \
    Sources/Views/StandBy/*.swift \
    Sources/Windows/*.swift \
    Sources/Main.swift \
    -o "$BUILD_DIR/AmpNotch"

echo "[2/4] Assembling AmpNotch.app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/AmpNotch" "$APP_DIR/Contents/MacOS/"
cp Resources/Info.plist "$APP_DIR/Contents/"
cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/"
cp Resources/AppIcon.png "$APP_DIR/Contents/Resources/"
cp -R Extension/AmpsoriaConnected "$APP_DIR/Contents/Resources/BrowserExtension"
cp 'Resources/Extension Setup.txt' "$APP_DIR/Contents/Resources/"
for icon in AmpNotch_Menubar_icon.png MenuBarIconTemplate.pdf MenuBarIconTemplate.png MenuBarIconTemplate@2x.png; do
    if [ -f "Resources/$icon" ]; then
        cp "Resources/$icon" "$APP_DIR/Contents/Resources/"
    fi
done
if [ -f Resources/CivilWarArtwork.jpg ]; then
    cp Resources/CivilWarArtwork.jpg "$APP_DIR/Contents/Resources/"
fi

echo "[3/4] Code signing application..."
codesign --force --deep --sign - "$APP_DIR"

echo "[4/4] Verifying bundle..."
codesign -vvv --deep --strict "$APP_DIR"

echo "=== Build complete: $APP_DIR ==="
