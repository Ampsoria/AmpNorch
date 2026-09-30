import AppKit
import CoreGraphics

// Exact Points for macOS Finder Window: 640 x 400 pt
let ptWidth: CGFloat = 640
let ptHeight: CGFloat = 400
let scale: CGFloat = 2.0 // Retina @2x (1280 x 800 px)

let pxWidth = Int(ptWidth * scale)
let pxHeight = Int(ptHeight * scale)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pxWidth,
    pixelsHigh: pxHeight,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Failed to create NSBitmapImageRep")
}

// CRITICAL: Setting rep.size to ptWidth x ptHeight tells macOS Finder
// that this 1280x800 px image is a @2x image designed for a 640x400 pt window!
rep.size = NSSize(width: ptWidth, height: ptHeight)

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("Failed to create NSGraphicsContext")
}
NSGraphicsContext.current = context
let ctx = context.cgContext

// Scale drawing coordinates so we can draw using 640 x 400 point coordinates directly!
ctx.scaleBy(x: scale, y: scale)

// 1. Sleek dark gradient background
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    CGColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0),
    CGColor(red: 0.08, green: 0.11, blue: 0.20, alpha: 1.0),
    CGColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1.0)
] as CFArray

let locations: [CGFloat] = [0.0, 0.5, 1.0]
if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: locations) {
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: ptHeight), end: CGPoint(x: ptWidth, y: 0), options: [])
}

// 2. Ambient glows behind drop zones
func drawGlow(center: CGPoint, radius: CGFloat, color: CGColor) {
    let glowColors = [color, color.copy(alpha: 0.0)!] as CFArray
    if let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(glowGradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }
}

// Drop zones centers at y=210 from bottom (meaning y=190 from top in 400pt height)
drawGlow(center: CGPoint(x: 160, y: 210), radius: 120, color: CGColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.25))
drawGlow(center: CGPoint(x: 480, y: 210), radius: 120, color: CGColor(red: 0.15, green: 0.85, blue: 0.65, alpha: 0.20))

// 3. Drop Zone target plates
func drawPlate(rect: CGRect, strokeColor: NSColor, fillColor: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 20, yRadius: 20)
    fillColor.setFill()
    path.fill()
    strokeColor.setStroke()
    path.lineWidth = 1.5
    let dash: [CGFloat] = [6.0, 6.0]
    path.setLineDash(dash, count: 2, phase: 0.0)
    path.stroke()
}

drawPlate(
    rect: CGRect(x: 95, y: 145, width: 130, height: 130),
    strokeColor: NSColor(calibratedRed: 0.4, green: 0.7, blue: 1.0, alpha: 0.5),
    fillColor: NSColor(calibratedRed: 0.1, green: 0.2, blue: 0.4, alpha: 0.15)
)

drawPlate(
    rect: CGRect(x: 415, y: 145, width: 130, height: 130),
    strokeColor: NSColor(calibratedRed: 0.2, green: 0.85, blue: 0.6, alpha: 0.5),
    fillColor: NSColor(calibratedRed: 0.05, green: 0.3, blue: 0.2, alpha: 0.15)
)

// 4. Arrow connecting the two icons
let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 260, y: 210))
arrowPath.line(to: NSPoint(x: 375, y: 210))
arrowPath.lineWidth = 3.5
let dashArr: [CGFloat] = [8.0, 6.0]
arrowPath.setLineDash(dashArr, count: 2, phase: 0.0)
NSColor(calibratedRed: 0.4, green: 0.75, blue: 1.0, alpha: 0.75).setStroke()
arrowPath.stroke()

let headPath = NSBezierPath()
headPath.move(to: NSPoint(x: 368, y: 224))
headPath.line(to: NSPoint(x: 388, y: 210))
headPath.line(to: NSPoint(x: 368, y: 196))
headPath.lineWidth = 3.5
headPath.lineCapStyle = .round
headPath.lineJoinStyle = .round
NSColor(calibratedRed: 0.4, green: 0.75, blue: 1.0, alpha: 0.9).setStroke()
headPath.stroke()

let arrowLabelAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.55, green: 0.8, blue: 1.0, alpha: 0.85)
]
let arrowLabelStr = "DRAG TO INSTALL"
let arrowLabelSize = arrowLabelStr.size(withAttributes: arrowLabelAttrs)
arrowLabelStr.draw(at: NSPoint(x: (ptWidth - arrowLabelSize.width) / 2, y: 222), withAttributes: arrowLabelAttrs)

// 5. Header Typography (Top Center)
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 26, weight: .bold),
    .foregroundColor: NSColor.white
]
let titleStr = "AmpNotch"
let titleSize = titleStr.size(withAttributes: titleAttrs)
titleStr.draw(at: NSPoint(x: (ptWidth - titleSize.width) / 2, y: 345), withAttributes: titleAttrs)

let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.75, green: 0.82, blue: 0.95, alpha: 0.85)
]
let subStr = "Dynamic Notch & iOS StandBy for MacBook"
let subSize = subStr.size(withAttributes: subtitleAttrs)
subStr.draw(at: NSPoint(x: (ptWidth - subSize.width) / 2, y: 322), withAttributes: subtitleAttrs)

// 6. Bottom Banner with Ampsoria branding & copyright
let bottomBannerRect = CGRect(x: 50, y: 20, width: ptWidth - 100, height: 46)
let bottomBannerPath = NSBezierPath(roundedRect: bottomBannerRect, xRadius: 12, yRadius: 12)
NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.16, alpha: 0.85).setFill()
bottomBannerPath.fill()
NSColor(calibratedRed: 0.25, green: 0.45, blue: 0.75, alpha: 0.35).setStroke()
bottomBannerPath.lineWidth = 1.0
bottomBannerPath.stroke()

let creditAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11.5, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.95, green: 0.98, blue: 1.0, alpha: 0.95)
]
let creditStr = "Developed by Ampsoria  •  GitHub: Ampsoria  •  Facebook: Ampsoria"
let creditSize = creditStr.size(withAttributes: creditAttrs)
creditStr.draw(at: NSPoint(x: (ptWidth - creditSize.width) / 2, y: 44), withAttributes: creditAttrs)

let copyAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 9.5, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.65, green: 0.75, blue: 0.90, alpha: 0.75)
]
let copyStr = "Copyright © 2026 Ampsoria. All rights reserved."
let copySize = copyStr.size(withAttributes: copyAttrs)
copyStr.draw(at: NSPoint(x: (ptWidth - copySize.width) / 2, y: 28), withAttributes: copyAttrs)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to convert image to PNG")
}

let outputPath = "/Users/ampsoria/Amp_NotchMac/Resources/dmg_background.png"
try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Successfully generated pixel-perfect DMG background at \(outputPath)")
