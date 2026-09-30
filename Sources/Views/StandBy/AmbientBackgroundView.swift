import SwiftUI

public struct AmbientBackgroundView: View {
    public var artwork: NSImage?
    @State private var animateGradients: Bool = false
    
    public init(artwork: NSImage? = nil) {
        self.artwork = artwork
    }
    
    public var body: some View {
        ZStack {
            // Dark Base
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Fluid Animated Blobs
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                // Color 1: Deep Purple / Violet
                Circle()
                    .fill(Color(red: 0.45, green: 0.15, blue: 0.65).opacity(0.45))
                    .frame(width: w * 0.7, height: w * 0.7)
                    .offset(
                        x: animateGradients ? -w * 0.15 : w * 0.1,
                        y: animateGradients ? -h * 0.1 : h * 0.15
                    )
                
                // Color 2: Sapphire Blue / Cyan
                Circle()
                    .fill(Color(red: 0.1, green: 0.35, blue: 0.8).opacity(0.4))
                    .frame(width: w * 0.65, height: w * 0.65)
                    .offset(
                        x: animateGradients ? w * 0.3 : -w * 0.1,
                        y: animateGradients ? h * 0.2 : -h * 0.15
                    )
                
                // Color 3: Warm Magenta / Rose
                Circle()
                    .fill(Color(red: 0.8, green: 0.2, blue: 0.45).opacity(0.35))
                    .frame(width: w * 0.6, height: w * 0.6)
                    .offset(
                        x: animateGradients ? -w * 0.2 : w * 0.25,
                        y: animateGradients ? h * 0.3 : -h * 0.05
                    )
            }
            .blur(radius: 80)
            
            // Subtle frosted glass overlay
            Rectangle()
                .fill(Color.black.opacity(0.45))
                .edgesIgnoringSafeArea(.all)
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 9.0).repeatForever(autoreverses: true)) {
                animateGradients.toggle()
            }
        }
    }
}
