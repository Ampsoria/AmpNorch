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
print("Image dimensions: \(width) x \(height)")

// Sample row across the middle (around y = height / 2 = 496)
// In CoreGraphics image coordinates, y is from top in bitmap representation
// Let's sample colors across horizontal line at y = 550 (middle of the boxes)
for x in stride(from: 100, to: width - 100, by: 20) {
    if let color = bitmap.colorAt(x: x, y: 550) {
        // Look for very high white/pink transparency/luminance (glass box)
        let lum = color.redComponent * 0.3 + color.greenComponent * 0.59 + color.blueComponent * 0.11
        if lum > 0.85 {
            // print("x: \(x), lum: \(lum)")
        }
    }
}

// Let's find the bounding box of the left box (x: 100...700) and right box (x: 800...1500)
// The boxes have a bright white semi-transparent fill and pink border.
// Let's find the outer frame coordinates
var leftBoxMinX = width, leftBoxMaxX = 0, leftBoxMinY = height, leftBoxMaxY = 0
var rightBoxMinX = width, rightBoxMaxX = 0, rightBoxMinY = height, rightBoxMaxY = 0

for y in 350...750 {
    for x in 150...650 {
        if let color = bitmap.colorAt(x: x, y: y) {
            let r = color.redComponent
            let g = color.greenComponent
            let b = color.blueComponent
            // Inside the box it's whitish/light pink: high R, G, B
            if r > 0.82 && g > 0.75 && b > 0.80 {
                leftBoxMinX = min(leftBoxMinX, x)
                leftBoxMaxX = max(leftBoxMaxX, x)
                leftBoxMinY = min(leftBoxMinY, y)
                leftBoxMaxY = max(leftBoxMaxY, y)
            }
        }
    }
    for x in 900...1450 {
        if let color = bitmap.colorAt(x: x, y: y) {
            let r = color.redComponent
            let g = color.greenComponent
            let b = color.blueComponent
            if r > 0.82 && g > 0.75 && b > 0.80 {
                rightBoxMinX = min(rightBoxMinX, x)
                rightBoxMaxX = max(rightBoxMaxX, x)
                rightBoxMinY = min(rightBoxMinY, y)
                rightBoxMaxY = max(rightBoxMaxY, y)
            }
        }
    }
}

print("Left Box: X: \(leftBoxMinX)...\(leftBoxMaxX), Y: \(leftBoxMinY)...\(leftBoxMaxY)")
let leftCenterX = (leftBoxMinX + leftBoxMaxX) / 2
let leftCenterY = (leftBoxMinY + leftBoxMaxY) / 2
print("Left Box Center: (\(leftCenterX), \(leftCenterY)), Size: \(leftBoxMaxX - leftBoxMinX) x \(leftBoxMaxY - leftBoxMinY)")

print("Right Box: X: \(rightBoxMinX)...\(rightBoxMaxX), Y: \(rightBoxMinY)...\(rightBoxMaxY)")
let rightCenterX = (rightBoxMinX + rightBoxMaxX) / 2
let rightCenterY = (rightBoxMinY + rightBoxMaxY) / 2
print("Right Box Center: (\(rightCenterX), \(rightCenterY)), Size: \(rightBoxMaxX - rightBoxMinX) x \(rightBoxMaxY - rightBoxMinY)")
