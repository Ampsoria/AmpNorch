import SwiftUI

public struct AudioVisualizerView: View {
    @ObservedObject private var audio = AudioMeterService.shared
    @ObservedObject private var player = MusicPlayerService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var maxHeight: CGFloat = 20
    public init(maxHeight: CGFloat = 20) { self.maxHeight = maxHeight }
    public var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<6) { index in
                Capsule().fill(Color(nsColor: player.artworkColor))
                    .frame(width: 3, height: height(index))
            }
        }
        .frame(width: 31, height: maxHeight)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.09), value: audio.levels)
        .accessibilityLabel(audio.enabled ? "Live audio waveform" : "Audio waveform disabled")
        .help(audio.enabled ? audio.status : "Enable live audio waveform in AmpNotch Settings")
    }
    private func height(_ index: Int) -> CGFloat {
        guard player.currentTrack?.isPlaying == true, !reduceMotion else { return 3 }
        let silhouette: [CGFloat] = [0.38, 0.55, 0.82, 1, 0.86, 0.46]
        return max(3, CGFloat(audio.levels[index]) * maxHeight * silhouette[index])
    }
}
