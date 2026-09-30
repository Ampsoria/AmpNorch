import SwiftUI

struct CompactAirPodsCaseView: View {
    let activity: NotchActivity
    let notchWidth: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lidOpen = false

    var body: some View {
        Button {
            NotchPresentationService.shared.isActivityExpanded = true
        } label: {
            HStack(spacing: 0) {
                AirPodsCaseArtwork(openAmount: reduceMotion || lidOpen ? 1 : 0)
                    .scaleEffect(0.5)
                    .frame(width: 32, height: 28)
                    .frame(width: 46)
                Color.clear.frame(width: notchWidth)
                VStack(spacing: 0) {
                    Text("Case").font(.system(size: 8, weight: .medium)).foregroundStyle(.white.opacity(0.65))
                    Text("Open").font(.system(size: 10, weight: .semibold))
                }.frame(width: 46)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .help("Nearby · \(activity.title)\n\(activity.subtitle)\nClick for details")
        .accessibilityLabel("Nearby \(activity.title), \(activity.subtitle)")
        .accessibilityHint("Show AirPods details")
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) {
                lidOpen = true
            }
        }
    }
}
