import SwiftUI
import AppKit

enum NotchGlassStyle: String, CaseIterable {
    case clear, regular, black

    var title: String {
        switch self {
        case .clear: return "Liquid Glass — Clear"
        case .regular: return "Liquid Glass — Regular"
        case .black: return "Classic Black"
        }
    }
}

/// One native material pass. Never stack a blur or opaque fill over Liquid Glass.
struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .windowBackgroundColor),
                               in: RoundedRectangle(cornerRadius: cornerRadius))
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content.background(VisualEffectBlur(material: .hudWindow, cornerRadius: cornerRadius))
        }
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 20) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }
}
