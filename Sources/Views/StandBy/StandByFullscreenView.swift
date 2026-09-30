import SwiftUI

public struct StandByFullscreenView: View {
    @ObservedObject private var player = MusicPlayerService.shared
    public init() {}
    public var body: some View {
        ZStack {
            Color.black
            if let artwork = player.currentTrack?.artworkImage {
                GeometryReader { geo in
                    Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                        .blur(radius: 35).overlay(.black.opacity(0.65))
                }
            }
            VStack(spacing: 20) {
                HStack {
                    Text("StandBy").font(.headline).foregroundStyle(.secondary)
                    Spacer()
                    Button { IdleTrackerService.shared.dismissStandBy() } label: { Label("Close", systemImage: "xmark") }
                        .buttonStyle(.bordered).keyboardShortcut(.cancelAction)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 0) {
                        Text(context.date, format: .dateTime.weekday(.wide).month(.wide).day()).font(.title3)
                        Text(context.date, style: .time).font(.system(size: 80, weight: .semibold, design: .rounded))
                    }
                }
                WidgetGalleryView()
                if let track = player.currentTrack {
                    HStack(spacing: 50) {
                        VStack(spacing: 24) {
                            if let image = track.artworkImage {
                                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 260, maxHeight: 260).clipShape(RoundedRectangle(cornerRadius: 20))
                            }
                            NowPlayingContent(track: track).padding(20).liquidGlass().frame(width: 350)
                            if let error = player.errorMessage { Text(error).font(.caption).foregroundStyle(.orange) }
                        }
                        StandByLyricsSection(track: track).frame(maxWidth: .infinity)
                    }.frame(maxWidth: 1100, maxHeight: .infinity)
                } else {
                    Spacer()
                    Label("Play music to see controls and lyrics", systemImage: "music.note").font(.title2).foregroundStyle(.secondary)
                    Spacer()
                }
                Text("Press Escape or Close to return to your desktop").font(.caption).foregroundStyle(.secondary)
            }.padding(40)
        }.foregroundStyle(.white).preferredColorScheme(.dark).ignoresSafeArea()
    }
}

struct StandByLyricsSection: View {
    let track: TrackInfo
    @ObservedObject private var lyrics = LyricsService.shared
    @ObservedObject private var player = MusicPlayerService.shared
    var body: some View {
        if lyrics.isLoading { ProgressView("Finding lyrics…") }
        else if let data = lyrics.currentLyrics {
            if data.isSynced {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            ForEach(Array(data.lines.enumerated()), id: \.element.id) { index, line in
                                Button { player.seek(to: line.time) } label: {
                                    Text(line.text).font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(index == data.activeIndex(for: track.position) ? .white : .white.opacity(0.35))
                                        .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.plain).disabled(!track.canSeek).id(line.id)
                            }
                        }.padding(.vertical, 30)
                    }
                    .onChange(of: data.activeIndex(for: track.position)) { index in
                        if let index, data.lines.indices.contains(index) {
                            withAnimation { proxy.scrollTo(data.lines[index].id, anchor: .center) }
                        }
                    }
                }
            } else { ScrollView { Text(data.plainText).font(.title2).frame(maxWidth: .infinity, alignment: .leading) } }
        } else { Text("Lyrics unavailable for this track").foregroundStyle(.secondary) }
    }
}
