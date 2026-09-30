import SwiftUI

public struct MarqueeText: View {
    public let text: String
    public let font: Font
    public let color: Color
    
    @State private var offset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    
    public init(text: String, font: Font = .system(size: 13, weight: .semibold), color: Color = .white) {
        self.text = text
        self.font = font
        self.color = color
    }
    
    public var body: some View {
        GeometryReader { geo in
            let diff = contentWidth - geo.size.width
            
            ZStack(alignment: .leading) {
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .lineLimit(1)
                    .fixedSize()
                    .background(
                        GeometryReader { textGeo in
                            Color.clear.onAppear {
                                contentWidth = textGeo.size.width
                                containerWidth = geo.size.width
                            }
                        }
                    )
                    .offset(x: offset)
                    .onAppear {
                        if diff > 0 {
                            withAnimation(
                                Animation.linear(duration: Double(diff) * 0.08 + 3.0)
                                    .delay(1.5)
                                    .repeatForever(autoreverses: true)
                            ) {
                                offset = -diff - 10
                            }
                        }
                    }
            }
            .clipped()
        }
    }
}
