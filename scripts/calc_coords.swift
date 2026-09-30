import AppKit

let imageURL = URL(fileURLWithPath: "/Users/ampsoria/Amp_NotchMac/Resources/AmpNotch_Background.png")
guard let nsImage = NSImage(contentsOf: imageURL),
      let tiffData = nsImage.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData) else {
    fatalError()
}

// Let's test horizontal centers
// In 1586 x 992 image:
// Left box: x = 228 to 600 -> center is (228 + 600) / 2 = 414 px
// Top is around 410, bottom is 745 -> center Y is (410 + 745) / 2 = 577 px
// Right box:
// The arrow is in the center: width / 2 = 793 px.
// Arrow starts around 610 and ends around 970!
// So Right box starts around 975!
// And ends around 1350 (975 + 372 = 1347 px, symmetrical to left box which is 372 px wide!).
// Let's verify width of right box:
// Left box distance from left edge: 228 px
// Right box distance from right edge: 1586 - 1350 = 236 px!
// Symmetrical!
let leftCenterX: CGFloat = 414.0
let rightCenterX: CGFloat = 1162.0 // (975 + 1350) / 2 = 1162.5
let centerY: CGFloat = 578.0

print("Left box center in 1586x992: (\(leftCenterX), \(centerY))")
print("Right box center in 1586x992: (\(rightCenterX), \(centerY))")

// Now, what scale should we use for Finder?
// If we use 1586 x 992 at 2x Retina:
// Logical size for Finder:
let finderWidth: CGFloat = 1586.0 / 2.0 // 793 pt
let finderHeight: CGFloat = 992.0 / 2.0 // 496 pt

print("Finder Window Size: \(finderWidth) x \(finderHeight) pt")
print("AmpNotch.app icon position in Finder: { \(leftCenterX / 2.0), \(centerY / 2.0) } = { \(Int(leftCenterX / 2.0)), \(Int(centerY / 2.0)) }")
print("Applications icon position in Finder: { \(rightCenterX / 2.0), \(centerY / 2.0) } = { \(Int(rightCenterX / 2.0)), \(Int(centerY / 2.0)) }")
