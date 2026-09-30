import Foundation
import CoreGraphics

/// Panels stay below the system clock and above the system sign-in controls.
/// Coordinates are local to the display, with AppKit's bottom-left origin.
struct LockScreenLayout {
    let artworkSize: CGFloat
    let music: CGRect
    let lyrics: CGRect

    init(size: CGSize) {
        let margin = max(24, size.width * 0.075)
        let bottom = max(180, size.height * 0.21)
        let top = size.height * 0.69
        let available = max(140, top - bottom)
        let width = min(320, size.width * 0.29)
        artworkSize = available >= 300 ? min(width, available - 154) : 0
        music = CGRect(x: margin, y: bottom, width: width,
                       height: artworkSize > 0 ? artworkSize + 154 : 140)
        lyrics = CGRect(x: size.width * 0.54, y: bottom,
                        width: max(180, size.width * 0.385), height: available)
    }
}

struct LockScreenVisibility {
    var enabled = true
    var locked = false
    var onConsole = false
    var displayAwake = true
    var hasTrack = false
    var shouldPresent: Bool { enabled && locked && onConsole && displayAwake && hasTrack }
}
