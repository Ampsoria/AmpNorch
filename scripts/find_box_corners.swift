import AppKit

let imageURL = URL(fileURLWithPath: "/Users/ampsoria/Amp_NotchMac/Resources/AmpNotch_Background.png")
guard let nsImage = NSImage(contentsOf: imageURL),
      let tiffData = nsImage.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData) else {
    fatalError()
}

// Left Box:
// Let's find exact top edge around x=415
for y in 380...450 {
    if let c = bitmap.colorAt(x: 415, y: y) {
        if c.redComponent > 0.85 && c.greenComponent < 0.65 && c.blueComponent > 0.55 {
            print("Left Box Top border at y=\(y)")
            break
        }
    }
}

// Right Box:
// Let's find exact left and right edge at y=580
for x in 950...1050 {
    if let c = bitmap.colorAt(x: x, y: 580) {
        if c.redComponent > 0.85 && c.greenComponent < 0.65 && c.blueComponent > 0.55 {
            print("Right Box Left border at x=\(x)")
            break
        }
    }
}

for x in stride(from: 1400, through: 1300, by: -1) {
    if let c = bitmap.colorAt(x: x, y: 580) {
        if c.redComponent > 0.85 && c.greenComponent < 0.65 && c.blueComponent > 0.55 {
            print("Right Box Right border at x=\(x)")
            break
        }
    }
}

for y in 380...450 {
    if let c = bitmap.colorAt(x: 1180, y: y) {
        if c.redComponent > 0.85 && c.greenComponent < 0.65 && c.blueComponent > 0.55 {
            print("Right Box Top border at y=\(y)")
            break
        }
    }
}
