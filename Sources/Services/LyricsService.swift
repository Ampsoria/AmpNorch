import Foundation
import Combine

public final class LyricsService: ObservableObject {
    public static let shared = LyricsService()
    @Published public private(set) var currentLyrics: LyricsData?
    @Published public private(set) var isLoading = false
    private var cache: [String: LyricsData] = [:]
    private var currentKey: String?
    private var request: URLSessionDataTask?
    public init() {}
    public func clear() {
        request?.cancel(); request = nil; currentKey = nil; currentLyrics = nil; isLoading = false
    }
    public func fetchLyrics(for track: TrackInfo) {
        let key = track.identity
        guard key != currentKey else { return }
        request?.cancel(); currentKey = key; currentLyrics = nil
        if let cached = cache[key] { currentLyrics = cached; isLoading = false; return }
        guard track.duration > 0 else { isLoading = false; return }
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [.init(name: "track_name", value: track.title), .init(name: "artist_name", value: track.artist),
                                 .init(name: "duration", value: String(Int(track.duration)))]
        if !track.album.isEmpty && track.playerType != .browser { components.queryItems?.append(.init(name: "album_name", value: track.album)) }
        guard let url = components.url else { isLoading = false; return }
        var urlRequest = URLRequest(url: url); urlRequest.timeoutInterval = 8
        urlRequest.setValue("AmpNotch/1.2.0", forHTTPHeaderField: "User-Agent")
        isLoading = true
        request = URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, _ in
            var lyrics: LyricsData?
            if (response as? HTTPURLResponse)?.statusCode == 200, let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if json["instrumental"] as? Bool == true { lyrics = LyricsData(plainText: "Instrumental") }
                else if let synced = json["syncedLyrics"] as? String, !synced.isEmpty { lyrics = .parseLRC(synced) }
                else if let plain = json["plainLyrics"] as? String, !plain.isEmpty { lyrics = LyricsData(plainText: plain) }
            }
            DispatchQueue.main.async {
                guard let self, self.currentKey == key else { return }
                self.currentLyrics = lyrics; self.isLoading = false
                if let lyrics {
                    if self.cache.count >= 50 { self.cache.removeAll() }
                    self.cache[key] = lyrics
                }
            }
        }
        request?.resume()
    }
}
