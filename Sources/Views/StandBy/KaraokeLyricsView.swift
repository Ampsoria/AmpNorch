import SwiftUI

public struct KaraokeLyricsView: View {
    @ObservedObject var player = MusicPlayerService.shared
    @ObservedObject var lyricsService = LyricsService.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "quote.bubble.fill")
                    .foregroundColor(.white.opacity(0.8))
                Text("LYRICS")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(2)
                
                Spacer()
                
                if lyricsService.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            
            if let lyrics = lyricsService.currentLyrics, lyrics.isSynced && !lyrics.lines.isEmpty {
                let activeIndex = lyrics.activeIndex(for: player.currentTrack?.position ?? 0) ?? 0
                
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            // Top padding so first line can be centered
                            Spacer().frame(height: 80)
                            
                            ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                                let isActive = index == activeIndex
                                let isPast = index < activeIndex
                                
                                Button(action: {
                                    player.seek(to: line.time)
                                }) {
                                    Text(line.text)
                                        .font(.system(
                                            size: isActive ? 24 : 18,
                                            weight: isActive ? .bold : .medium,
                                            design: .rounded
                                        ))
                                        .foregroundColor(
                                            isActive ? .white : (isPast ? .white.opacity(0.3) : .white.opacity(0.55))
                                        )
                                        .scaleEffect(isActive ? 1.03 : 1.0, anchor: .leading)
                                        .shadow(
                                            color: isActive ? Color.white.opacity(0.4) : Color.clear,
                                            radius: 10, x: 0, y: 0
                                        )
                                        .multilineTextAlignment(.leading)
                                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isActive)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .id(line.id)
                            }
                            
                            // Bottom padding
                            Spacer().frame(height: 120)
                        }
                        .padding(.horizontal, 24)
                    }
                    .onChange(of: activeIndex) { newIdx in
                        if lyrics.lines.indices.contains(newIdx) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                proxy.scrollTo(lyrics.lines[newIdx].id, anchor: .center)
                            }
                        }
                    }
                    .onAppear {
                        if lyrics.lines.indices.contains(activeIndex) {
                            proxy.scrollTo(lyrics.lines[activeIndex].id, anchor: .center)
                        }
                    }
                }
            } else if let lyrics = lyricsService.currentLyrics, !lyrics.plainText.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(lyrics.plainText)
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .lineSpacing(10)
                        .padding(24)
                }
            } else if lyricsService.isLoading {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Searching lyrics...")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "music.quarternote.3")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No lyrics available for this song")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
