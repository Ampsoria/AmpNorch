import SwiftUI

struct LockScreenMusicView: View {
    let artworkSize: CGFloat
    @ObservedObject private var player = MusicPlayerService.shared

    var body: some View {
        if let track = player.currentTrack {
            VStack(spacing: 14) {
                if artworkSize > 0 {
                    MusicSceneArtwork(image: track.artworkImage, size: artworkSize)
                }
                MusicSceneControls(track: track)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white).preferredColorScheme(.dark)
        }
    }
}

struct MusicSceneArtwork: View {
    let image: NSImage?
    let size: CGFloat
    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack { Color(white: 0.12); Image(systemName: "music.note").font(.system(size: size * 0.25)) }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.16)))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .accessibilityLabel("Album artwork")
    }
}

/// Only media actions are exposed while locked. No app launch, menus, settings,
/// lyric seeking or keyboard focus is reachable through these panels.
struct MusicSceneControls: View {
    let track: TrackInfo
    @ObservedObject private var player = MusicPlayerService.shared
    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 3) {
                Text(track.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(track.artist).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack(spacing: 5) {
                Text(track.formattedPosition).frame(width: 32, alignment: .leading)
                PlaybackSlider(position: track.position, duration: track.duration,
                               isEnabled: track.canSeek && !player.commandPending) { position in
                    guard player.currentTrack?.identity == track.identity else { return }
                    player.seek(to: position)
                }.id(track.identity)
                Text(track.formattedRemaining).frame(width: 36, alignment: .trailing)
            }.font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary)
            HStack(spacing: 36) {
                Button { player.previousTrack() } label: { Image(systemName: "backward.fill") }
                    .disabled(!track.canSkip).accessibilityLabel("Previous track")
                Button { player.togglePlayPause() } label: {
                    Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 25)).frame(width: 30)
                }.accessibilityLabel(track.isPlaying ? "Pause playback" : "Resume playback")
                Button { player.nextTrack() } label: { Image(systemName: "forward.fill") }
                    .disabled(!track.canSkip).accessibilityLabel("Next track")
            }.font(.system(size: 20)).buttonStyle(.plain).disabled(player.commandPending)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity).background(ClearMusicGlassBackground(cornerRadius: 20))
    }
}

struct LockScreenLyricsView: View {
    @ObservedObject private var player = MusicPlayerService.shared
    @ObservedObject private var lyrics = LyricsService.shared
    var body: some View {
        FocusedLyricsView(data: lyrics.currentLyrics, position: player.currentTrack?.position ?? 0,
                          loading: lyrics.isLoading)
            .id(player.currentTrack?.identity)
            .foregroundStyle(.white).preferredColorScheme(.dark)
    }
}

/// Persistent lyric rows move through a fixed viewport. Only a timestamp change
/// starts a short animation; playback ticks never recreate the rows or scroll.
struct FocusedLyricsView: View {
    let data: LyricsData?
    let position: TimeInterval
    let loading: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let fontSize = min(44, max(22, geometry.size.width * 0.087))
            Group {
                if loading {
                    Text("Finding lyrics…").font(.title3).foregroundStyle(.secondary)
                } else if let data, data.isSynced, !data.lines.isEmpty {
                    scrollingLyrics(data, fontSize: fontSize, height: geometry.size.height)
                } else if let data, !data.plainText.isEmpty {
                    Text(data.plainText == "Instrumental" ? "Instrumental" : "Synced lyrics unavailable")
                        .font(.title3).foregroundStyle(.secondary)
                } else {
                    Text("Lyrics unavailable for this track").font(.title3).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }.padding(12).clipped()
    }

    private func scrollingLyrics(_ data: LyricsData, fontSize: CGFloat, height: CGFloat) -> some View {
        let active = data.activeIndex(for: position)
        let motion: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.65)
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    Text("•••").font(.system(size: fontSize)).foregroundStyle(.white.opacity(0.6))
                        .accessibilityLabel("Instrumental introduction")
                        .id("intro")
                    ForEach(Array(data.lines.enumerated()), id: \.element.id) { index, line in
                        // Keep font metrics and wrapping stable while emphasizing
                        // the current line, so the scroll target cannot jump.
                        Text(line.text)
                            .font(.system(size: fontSize, weight: .bold, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.white.opacity(index == active ? 1 : 0.32))
                            .scaleEffect(index == active ? 1 : 0.86, anchor: .leading)
                            .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                            .id(line.id)
                    }
                }
                .padding(.vertical, height / 2)
                .animation(motion, value: active)
            }
            .allowsHitTesting(false)
            .mask(LinearGradient(stops: [
                .init(color: .clear, location: 0), .init(color: .white, location: 0.17),
                .init(color: .white, location: 0.83), .init(color: .clear, location: 1)
            ], startPoint: .top, endPoint: .bottom))
            .onAppear {
                // First render / switching songs lands at the current timestamp.
                // It must not animate through every preceding lyric.
                if let active { proxy.scrollTo(data.lines[active].id, anchor: .center) }
                else { proxy.scrollTo("intro", anchor: .center) }
            }
            .onChange(of: active) { index in
                withAnimation(motion) {
                    if let index { proxy.scrollTo(data.lines[index].id, anchor: .center) }
                    else { proxy.scrollTo("intro", anchor: .center) }
                }
            }
        }
    }
}
