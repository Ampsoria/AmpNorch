import SwiftUI

public struct CompactNotchView: View {
    @ObservedObject private var player = MusicPlayerService.shared
    public var notchWidth: CGFloat
    public init(notchWidth: CGFloat = 185) { self.notchWidth = notchWidth }
    public var body: some View {
        HStack(spacing: 0) {
            Group {
                if let image = player.currentTrack?.artworkImage {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 22, height: 22).clipShape(RoundedRectangle(cornerRadius: 6))
                } else { Image(systemName: player.currentTrack?.playerType.iconName ?? "music.note") }
            }.frame(width: 46)
            Color.clear.frame(width: notchWidth)
            AudioVisualizerView(maxHeight: 19).frame(width: 46)
        }.font(.system(size: 13, weight: .semibold)).frame(maxHeight: .infinity)
    }
}
