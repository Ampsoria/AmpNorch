import AppKit

/// A small, cached palette from the real cover. Ignore near-black/white backgrounds.
enum ArtworkPalette {
    static func color(from image: NSImage?) -> NSColor {
        guard let image, let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return .init(white: 0.78, alpha: 1) }
        let size = 24
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        guard let context = CGContext(data: &bytes, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return .white }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))
        var bins: [Int: (count: Double, r: Double, g: Double, b: Double)] = [:]
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let r = Double(bytes[i])/255, g = Double(bytes[i+1])/255, b = Double(bytes[i+2])/255
            let bright = max(r,g,b), low = min(r,g,b)
            guard bytes[i+3] > 127, bright > 0.14, low < 0.9 else { continue }
            let key = (Int(bytes[i]) >> 5) * 64 + (Int(bytes[i+1]) >> 5) * 8 + (Int(bytes[i+2]) >> 5)
            let weight = 1 + (bright-low)*1.5
            let old = bins[key] ?? (0,0,0,0)
            bins[key] = (old.count + weight, old.r + r*weight, old.g + g*weight, old.b + b*weight)
        }
        guard let dominant = bins.values.max(by: { $0.count < $1.count }) else { return .init(white: 0.78, alpha: 1) }
        let color = NSColor(deviceRed: dominant.r/dominant.count, green: dominant.g/dominant.count,
                            blue: dominant.b/dominant.count, alpha: 1)
        return NSColor(calibratedHue: color.hueComponent, saturation: min(color.saturationComponent,0.65),
                       brightness: min(max(color.brightnessComponent,0.6),0.92), alpha: 1)
    }
}
