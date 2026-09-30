import AppKit

enum StatusBarIcon {
    static func load(from bundle: Bundle = .main) -> NSImage? {
        let artwork: NSImage?
        let isTemplate: Bool
        if let url = bundle.url(forResource: "AmpNotch_Menubar_icon", withExtension: "png"),
           let image = NSImage(contentsOf: url), image.isValid {
            artwork = image
            isTemplate = false
        } else if let url = bundle.url(forResource: "MenuBarIconTemplate", withExtension: "pdf"),
           let image = NSImage(contentsOf: url), image.isValid {
            artwork = image
            isTemplate = true
        } else {
            artwork = bundle.image(forResource: "MenuBarIconTemplate")
            isTemplate = true
        }
        guard let artwork, artwork.isValid, artwork.size.width > 0, artwork.size.height > 0 else {
            return NSImage(systemSymbolName: "waveform", accessibilityDescription: "AmpNotch")
        }
        let side: CGFloat = 18
        let scale = min(side / artwork.size.width, side / artwork.size.height)
        let size = NSSize(width: artwork.size.width * scale, height: artwork.size.height * scale)
        let rect = NSRect(x: (side - size.width) / 2, y: (side - size.height) / 2,
                          width: size.width, height: size.height)
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            NSGraphicsContext.current?.imageInterpolation = .high
            artwork.draw(in: rect)
            return true
        }
        image.isTemplate = isTemplate
        image.accessibilityDescription = "AmpNotch"
        return image
    }
}
