import SwiftUI

/// Vector case artwork: a hinged lid, two earbuds and a shaded charging case.
/// Drawn at 64 × 56, then scaled to the compact artwork slot without bitmap blur.
struct AirPodsCaseArtwork: View, Animatable {
    var openAmount: CGFloat
    var animatableData: CGFloat {
        get { openAmount }
        set { openAmount = newValue }
    }

    var body: some View {
        ZStack {
            // The lid moves behind the earbuds as it opens.
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [.white, Color(white: 0.68)], startPoint: .top, endPoint: .bottom))
                .overlay {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.7), lineWidth: 0.8)
                }
                .overlay {
                    Capsule().fill(Color(white: 0.25)).frame(width: 40, height: 5)
                        .offset(y: 2).opacity(Double(openAmount) * 0.8)
                }
                .frame(width: 52, height: 14)
                .scaleEffect(x: 1, y: 0.6 + openAmount * 0.4)
                .position(x: 32, y: 24 - openAmount * 16)

            ForEach(0..<2) { index in
                ZStack {
                    Capsule().fill(LinearGradient(colors: [.white, Color(white: 0.64)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 6, height: 18).offset(y: 7)
                    Ellipse().fill(.white).frame(width: 14, height: 11)
                    Ellipse().fill(Color(white: 0.14)).frame(width: 5, height: 3)
                        .offset(x: index == 0 ? -2 : 2, y: -1)
                }
                .frame(width: 16, height: 24)
                .rotationEffect(.degrees(index == 0 ? -10 : 10))
                .position(x: index == 0 ? 21 : 43, y: 23)
                .opacity(Double(openAmount))
            }

            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: Color(white: 0.91), location: 0.35),
                    .init(color: Color(white: 0.69), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.65), lineWidth: 0.8)
                }
                .overlay(alignment: .top) {
                    Capsule().fill(.black.opacity(0.2)).frame(width: 40, height: 1).padding(.top, 2)
                }
                .overlay {
                    Circle().fill(Color(red: 0.45, green: 0.95, blue: 0.55))
                        .frame(width: 2, height: 2).offset(y: -2)
                }
                .frame(width: 54, height: 28)
                .position(x: 32, y: 39)
        }
        .frame(width: 64, height: 56)
        .accessibilityHidden(true)
    }
}
