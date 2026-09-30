import AppKit
import CoreGraphics

let imageURL = URL(fileURLWithPath: "/Users/ampsoria/Amp_NotchMac/Resources/AmpNotch_Background.png")
guard let nsImage = NSImage(contentsOf: imageURL),
      let tiffData = nsImage.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData) else {
    fatalError("Failed to load image")
}

let width = bitmap.pixelsWide
let height = bitmap.pixelsHigh

// Let's sample along a horizontal line at y = 580 to find the borders of the boxes
print("Scanning horizontal line at y = 580:")
for x in stride(from: 50, to: width - 50, by: 5) {
    if let c = bitmap.colorAt(x: x, y: 580) {
        // Neon pink border has high red, low green, high blue (magenta/pink)
        let isPink = (c.redComponent > 0.85 && c.greenComponent < 0.55 && c.blueComponent > 0.55)
        if isPink {
            print("Pink border at x=\(x), y=580: R=\(c.redComponent), G=\(c.greenComponent), B=\(c.blueComponent)")
        }
    }
}

// Let's sample along vertical lines at x = 400 (center of left box) and x = 1170 (center of right box)
print("\nScanning vertical line at x = 400:")
for y in stride(from: 200, to: 900, by: 5) {
    if let c = bitmap.colorAt(x: 400, y: y) {
        let isPink = (c.redComponent > 0.85 && c.greenComponent < 0.55 && c.blueComponent > 0.55)
        if isPink {
            print("Left box top/bottom pink border at x=400, y=\(y)")
        }
    }
}

print("\nScanning vertical line at x = 1170:")
for y in stride(from: 200, to: 900, by: 5) {
    if let c = bitmap.colorAt(x: 1170, y: y) {
        let isPink = (c.redComponent > 0.85 && c.greenComponent < 0.55 && c.blueComponent > 0.55)
        if isPink {
            print("Right box top/bottom pink border at x=1170, y=\(y)")
        }
    }
}
