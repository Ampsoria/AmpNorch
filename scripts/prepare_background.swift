import AppKit

let inputURL = URL(fileURLWithPath: "/Users/ampsoria/Amp_NotchMac/Resources/AmpNotch_Background.png")
let outputURL = URL(fileURLWithPath: "/Users/ampsoria/Amp_NotchMac/Resources/dmg_background.png")

guard let img = NSImage(contentsOf: inputURL),
      let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else {
    fatalError("Failed to load input image")
}

let pxW = rep.pixelsWide
let pxH = rep.pixelsHigh
let ptW = CGFloat(pxW) / 2.0 // 793.0
let ptH = CGFloat(pxH) / 2.0 // 496.0

// Explicitly set the logical point size to half of pixel size (144 DPI @2x Retina)
rep.size = NSSize(width: ptW, height: ptH)

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to export PNG")
}

try pngData.write(to: outputURL)
print("Successfully prepared dmg_background.png: \(pxW)x\(pxH) px, \(ptW)x\(ptH) pt (144 DPI)")
