#!/usr/bin/env bash
# Package without controlling Finder. Reuse the existing installer layout.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"
if [[ "${1:-}" != "--skip-build" ]]; then bash scripts/build.sh; fi
codesign --verify --deep --strict build/AmpNotch.app
STAGE_DIR="$(mktemp -d "$PROJECT_DIR/build/release.XXXXXX")"
cp -R build/AmpNotch.app "$STAGE_DIR/"
cp 'build/AmpNotch.app/Contents/Resources/Extension Setup.txt' "$STAGE_DIR/Extension Setup.txt"
ln -s /Applications "$STAGE_DIR/Applications"
mkdir -p "$STAGE_DIR/.background" "$STAGE_DIR/About & Links"
cp Resources/dmg_background.png "$STAGE_DIR/.background/background.png"
cp Resources/dmg-layout.DS_Store "$STAGE_DIR/.DS_Store"
cp Resources/AppIcon.icns "$STAGE_DIR/.VolumeIcon.icns"
cp Resources/*.webloc Resources/LICENSE.txt 'Resources/About Ampsoria.txt' RELEASE_NOTES.md INTEGRATIONS.md "$STAGE_DIR/About & Links/"
SetFile -a V "$STAGE_DIR/About & Links" 2>/dev/null || true
SetFile -a C "$STAGE_DIR" 2>/dev/null || true
hdiutil create -volname 'AmpNotch by Ampsoria' -srcfolder "$STAGE_DIR" -format UDZO -imagekey zlib-level=9 -ov build/AmpNotch-next.dmg
hdiutil verify build/AmpNotch-next.dmg
mkdir -p build/backups
if [[ -f AmpNotch.dmg && ! -f build/backups/AmpNotch-before-1.1.dmg ]]; then
    cp AmpNotch.dmg build/backups/AmpNotch-before-1.1.dmg
fi
mv build/AmpNotch-next.dmg AmpNotch.dmg
shasum -a 256 AmpNotch.dmg
