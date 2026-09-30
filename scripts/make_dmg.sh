#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=== Packaging AmpNotch into Custom Styled DMG with Ampsoria Background ==="

# First ensure app is built
bash scripts/build.sh

STAGE_DIR="$PROJECT_DIR/build/dmg_stage"
TEMP_DMG="$PROJECT_DIR/build/temp_AmpNotch.dmg"
DMG_OUTPUT="$PROJECT_DIR/AmpNotch.dmg"
VOL_NAME="AmpNotch by Ampsoria"

rm -rf "$STAGE_DIR" "$TEMP_DMG" "$DMG_OUTPUT"
mkdir -p "$STAGE_DIR"

echo "[1/4] Copying AmpNotch.app to DMG stage..."
cp -R "$PROJECT_DIR/build/AmpNotch.app" "$STAGE_DIR/"

echo "[2/4] Adding Applications symlink, volume icon, and documentation..."
ln -s /Applications "$STAGE_DIR/Applications"

if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$STAGE_DIR/.VolumeIcon.icns"
    SetFile -c icnC "$STAGE_DIR/.VolumeIcon.icns" 2>/dev/null || true
fi

# Include documentation in a hidden folder or docs folder so it doesn't clutter the artwork
DOCS_DIR="$STAGE_DIR/About & Links"
mkdir -p "$DOCS_DIR"
cp "$PROJECT_DIR/Resources/About Ampsoria.txt" "$DOCS_DIR/"
cp "$PROJECT_DIR/Resources/LICENSE.txt" "$DOCS_DIR/"
cp "$PROJECT_DIR/Resources/GitHub (Ampsoria).webloc" "$DOCS_DIR/"
cp "$PROJECT_DIR/Resources/Facebook (Ampsoria).webloc" "$DOCS_DIR/"
SetFile -a V "$DOCS_DIR" 2>/dev/null || true # Hide docs folder from Finder view to keep artwork pristine

# Process user's AmpNotch_Background.png to ensure proper 144 DPI Retina scale
swift "$PROJECT_DIR/scripts/prepare_background.swift"
BG_IMAGE="$PROJECT_DIR/Resources/dmg_background.png"

echo "[3/4] Custom background detected. Creating and styling DMG window via Finder AppleScript..."
mkdir -p "$STAGE_DIR/.background"
cp "$BG_IMAGE" "$STAGE_DIR/.background/background.png"

# Detach any existing AmpNotch mounts to prevent volume name conflict
for mnt in $(mount | grep "/Volumes/AmpNotch" | sed 's/ on .*//'); do
    hdiutil detach "$mnt" -force 2>/dev/null || true
done
sleep 1

# Create temporary read/write disk image
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE_DIR" -ov -format UDRW "$TEMP_DMG"

# Mount disk image and capture device
ATTACH_OUT=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG")
DEV_NODE=$(echo "$ATTACH_OUT" | grep "/Volumes/" | awk '{print $1}')
ACTUAL_MOUNT=$(echo "$ATTACH_OUT" | grep "/Volumes/" | sed 's/.*\/Volumes\///')
ACTUAL_MOUNT="/Volumes/$ACTUAL_MOUNT"

echo "Mounted $VOL_NAME at $ACTUAL_MOUNT ($DEV_NODE)"

# Configure Finder window styling and positions via AppleScript
# Window width = 793 pt, height = 496 pt (matches 1586 x 992 px @ 2x Retina)
# Left box center: {208, 275}, Right box center: {582, 275}
osascript << EOF || true
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set pathbar visible of container window to false
        set the bounds of container window to {180, 100, 973, 632} -- 793 x 532 pt (496 pt content + 36 pt titlebar/margin)
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 120
        try
            set background picture of viewOptions to file ".background:background.png"
        end try
        try
            set position of item "AmpNotch.app" of container window to {208, 275}
            set position of item "Applications" of container window to {582, 275}
        end try
        close
        open
        update without registering applications
        delay 2
    end tell
    set selection to {}
end tell
EOF

# Ensure custom volume icon flag is set on the mounted root
SetFile -a C "$ACTUAL_MOUNT" 2>/dev/null || true

# Unmount cleanly
sync
hdiutil detach "$DEV_NODE" 2>/dev/null || hdiutil detach "$ACTUAL_MOUNT" -force 2>/dev/null || true

echo "[4/4] Converting to compressed final release DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_OUTPUT"
rm -f "$TEMP_DMG"
rm -rf "$STAGE_DIR"

echo "=== DMG Created Successfully with Ampsoria Background & Aligned Icons! ==="
ls -lh "$DMG_OUTPUT"
shasum -a 256 "$DMG_OUTPUT"
