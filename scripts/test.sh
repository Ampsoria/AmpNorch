#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -parse-as-library -target "$(uname -m)-apple-macos13.0" \
    Sources/Models/NotchActivity.swift Sources/Models/NotchGeometry.swift \
    Sources/Services/NotchPresentationService.swift \
    Sources/Views/Components/LiquidGlass.swift Sources/Views/Components/VisualEffectBlur.swift \
    Tests/NotchBehaviorTests.swift -o build/NotchBehaviorTests
build/NotchBehaviorTests
swiftc -parse-as-library -target "$(uname -m)-apple-macos13.0" \
    Sources/Models/TrackInfo.swift Sources/Models/LyricLine.swift Sources/Models/AirPodsAdvertisement.swift \
    Tests/MediaAndAirPodsTests.swift -o build/MediaAndAirPodsTests
build/MediaAndAirPodsTests
node Tests/browser-content.test.js
swiftc -parse-as-library Sources/Models/WaveformDSP.swift Sources/Models/ArtworkPalette.swift \
    Tests/WaveformTests.swift -o build/WaveformTests
build/WaveformTests
swiftc -parse-as-library Sources/Models/LockScreenLayout.swift Tests/LockScreenTests.swift -o build/LockScreenTests
build/LockScreenTests
