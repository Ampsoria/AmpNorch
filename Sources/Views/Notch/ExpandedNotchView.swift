import SwiftUI
import AppKit

public struct ExpandedNotchView: View {
    @ObservedObject private var player = MusicPlayerService.shared
    public var notchHeight: CGFloat
    public init(notchHeight: CGFloat = 32) { self.notchHeight = notchHeight }
    public var body: some View {
        VStack(spacing: 10) {
            if let track = player.currentTrack { NowPlayingContent(track: track) }
            else { idleContent }
            if let error = player.errorMessage {
                Text(error).font(.system(size: 11)).foregroundStyle(.orange).lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 18).padding(.top, notchHeight + 4).padding(.bottom, 10)
        .foregroundStyle(.white)
    }
    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "music.note").font(.system(size: 28))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nothing playing").font(.headline)
                    Text("Play music or connect your browser").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { SettingsWindowManager.shared.show() } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.plain).accessibilityLabel("Open settings")
            }
            HStack {
                Button("Open Music") { open("com.apple.Music") }
                Button("Open Spotify") { open("com.spotify.client") }
                Spacer()
            }.buttonStyle(.bordered)
            RecognitionButton()
        }
    }
    private func open(_ id: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            player.errorMessage = "That music app is not installed."; return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}

struct NowPlayingContent: View {
    let track: TrackInfo
    @ObservedObject private var player = MusicPlayerService.shared
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button { player.openCurrentSource() } label: {
                    Group {
                        if let image = track.artworkImage { Image(nsImage: image).resizable().aspectRatio(contentMode: .fill) }
                        else { Image(systemName: track.playerType.iconName).font(.system(size: 25)).frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(0.1)) }
                    }
                    .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).accessibilityLabel("Open playing app")
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Text(track.artist).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                AudioVisualizerView(maxHeight: 20)
                Menu {
                    Button("Choose automatically") { player.selectSource(nil) }
                    ForEach(player.sources, id: \.sourceID) { source in
                        Button("\(source.playerType.rawValue): \(source.title)") { player.selectSource(source.sourceID) }
                    }
                    Divider()
                    Button("Open playing app") { player.openCurrentSource() }
                    Button("Settings…") { SettingsWindowManager.shared.show() }
                    Button("Collapse notch") { NotchPresentationService.shared.isExpanded = false }
                    Divider()
                    Button("Quit AmpNotch") { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24, height: 24)
                .accessibilityLabel("Playback source and settings")
            }
            HStack(spacing: 6) {
                Text(track.formattedPosition).frame(width: 35, alignment: .leading)
                PlaybackSlider(position: track.position, duration: track.duration,
                               isEnabled: track.canSeek && !player.commandPending) { position in
                    guard player.currentTrack?.identity == track.identity else { return }
                    player.seek(to: position)
                }
                .id(track.identity)
                Text(track.formattedRemaining).frame(width: 40, alignment: .trailing)
            }.font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary)
            HStack {
                if let shuffle = track.shuffle {
                    Button { player.toggleShuffle() } label: { Image(systemName: "shuffle").foregroundStyle(shuffle ? .green : .white.opacity(0.65)) }
                        .accessibilityLabel(shuffle ? "Turn shuffle off" : "Turn shuffle on")
                } else { Image(systemName: track.playerType.iconName).foregroundStyle(.secondary) }
                Spacer()
                Button { player.previousTrack() } label: { Image(systemName: "backward.fill") }
                    .disabled(!track.canSkip).accessibilityLabel("Previous track")
                Spacer()
                Button { player.togglePlayPause() } label: {
                    Image(systemName: track.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 23))
                }.accessibilityLabel(track.isPlaying ? "Pause playback" : "Resume playback")
                Spacer()
                Button { player.nextTrack() } label: { Image(systemName: "forward.fill") }
                    .disabled(!track.canSkip).accessibilityLabel("Next track")
                Spacer()
                Button { IdleTrackerService.shared.triggerStandByNow() } label: { Image(systemName: "rectangle.expand.vertical") }
                    .accessibilityLabel("Open StandBy")
            }
            .font(.system(size: 17)).buttonStyle(.plain).disabled(player.commandPending)
        }
    }
}

struct RecognitionButton: View {
    @ObservedObject private var service = ShazamService.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { service.toggleListening() } label: {
                Label(service.isListening ? "Stop listening" : "Identify a song", systemImage: "shazam.logo.fill")
            }.buttonStyle(.plain)
            if let result = service.matchResult { Text(result).font(.caption).lineLimit(2) }
            if let error = service.errorMessage { Text(error).font(.caption).foregroundStyle(.orange).lineLimit(2) }
        }
    }
}
