import AppKit
import SwiftUI

/// One untinted native glass surface. Opacity applies only to the material,
/// leaving labels and controls crisp instead of fading the entire card.
struct ClearMusicGlassBackground: NSViewRepresentable {
    var cornerRadius: CGFloat
    @ObservedObject private var glass = GlassAppearanceSettings.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ container: NSView, context: Context) {
        let tag = reduceTransparency ? 1 : 2
        if container.subviews.first?.tag != tag {
            container.subviews.forEach { $0.removeFromSuperview() }
            let surface: NSView
            if reduceTransparency {
                let solid = TaggedMusicSurface(tag: tag)
                solid.wantsLayer = true
                solid.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
                solid.layer?.cornerRadius = cornerRadius
                surface = solid
            } else if #available(macOS 26.0, *) {
                let glass = TaggedMusicGlass()
                glass.style = .clear
                glass.tintColor = nil
                glass.cornerRadius = cornerRadius
                surface = glass
            } else {
                let blur = TaggedMusicBlur()
                blur.material = .hudWindow
                blur.blendingMode = .behindWindow
                blur.state = .active
                blur.wantsLayer = true
                blur.layer?.cornerRadius = cornerRadius
                blur.layer?.masksToBounds = true
                surface = blur
            }
            surface.frame = container.bounds
            surface.autoresizingMask = [.width, .height]
            container.addSubview(surface)
        }
        container.subviews.first?.alphaValue = reduceTransparency ? 1 :
            CGFloat(GlassAppearanceSettings.validOpacity(glass.lockScreenOpacity))
    }
}

private final class TaggedMusicSurface: NSView {
    private let identifierTag: Int
    override var tag: Int { identifierTag }
    init(tag: Int) { identifierTag = tag; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
@available(macOS 26.0, *)
private final class TaggedMusicGlass: NSGlassEffectView { override var tag: Int { 2 } }
private final class TaggedMusicBlur: NSVisualEffectView { override var tag: Int { 2 } }
