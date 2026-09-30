import AppKit
import Combine

public final class MusicPlayerService: ObservableObject {
    public static let shared = MusicPlayerService()
    @Published public private(set) var currentTrack: TrackInfo?
    @Published var sources: [TrackInfo] = []
    @Published var errorMessage: String?
    @Published var artworkColor: NSColor = .init(white: 0.78, alpha: 1)
    @Published var commandPending = false
    private var selection = MediaSourceSelection()
    private let native = NativeMediaClient()
    private var pollTimer: Timer?
    private var positionTimer: Timer?
    private var pollInFlight = false
    private var commandGeneration = 0
    private var artworkTask: URLSessionDataTask?
    private var artworkKey: String?
    private let artworkCache = NSCache<NSString, NSImage>()
    private var lastSnapshotPosition: Double?
    private var anchor: (identity: String, position: Double, date: Date)?

    public init() {
        artworkCache.countLimit = 40
        startPolling()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, var track = self.currentTrack, track.isPlaying, let anchor = self.anchor,
                  anchor.identity == track.identity else { return }
            track.position = anchor.position + Date().timeIntervalSince(anchor.date)
            if track.duration > 0 { track.position = min(track.position, track.duration) }
            self.currentTrack = track
        }
    }
    public func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.pollCurrentPlayer() }
        pollTimer?.tolerance = 0.2
        pollCurrentPlayer()
    }
    public func stopPolling() { pollTimer?.invalidate(); pollTimer = nil }
    public func pollCurrentPlayer() {
        guard !pollInFlight, !commandPending else { return }
        pollInFlight = true
        let generation = commandGeneration
        native.poll { [weak self] results in
            guard let self else { return }
            self.pollInFlight = false
            guard generation == self.commandGeneration else { return }
            for result in results {
                if let track = result.track { self.selection.update(track) }
                else { self.selection.remove(result.type.rawValue) }
            }
            if let error = results.compactMap(\.error).first { self.errorMessage = error }
            else if !self.commandPending { self.errorMessage = nil }
            self.publishSelection()
        }
    }
    func receiveBrowserTrack(_ track: TrackInfo) { selection.update(track); publishSelection() }
    func removeBrowserSource(_ id: String) { selection.remove(id); publishSelection() }
    func selectSource(_ id: String?) { selection.preferredSource = id; publishSelection() }
    private func publishSelection() {
        sources = selection.tracks.values.sorted { $0.sourceID < $1.sourceID }
        guard var next = selection.selected else {
            currentTrack = nil; anchor = nil; lastSnapshotPosition = nil; artworkTask?.cancel(); artworkKey = nil
            LyricsService.shared.clear(); return
        }
        let changed = currentTrack?.identity != next.identity
        if !changed, next.artworkImage == nil { next.artworkImage = currentTrack?.artworkImage }
        if changed || lastSnapshotPosition != next.position || currentTrack?.isPlaying != next.isPlaying {
            anchor = (next.identity, next.position, Date())
            lastSnapshotPosition = next.position
        } else if let currentTrack { next.position = currentTrack.position }
        if changed || currentTrack?.artworkImage !== next.artworkImage { artworkColor = ArtworkPalette.color(from: next.artworkImage) }
        currentTrack = next
        if changed { LyricsService.shared.fetchLyrics(for: next) }
        loadArtwork(next)
    }
    private func loadArtwork(_ track: TrackInfo) {
        guard track.artworkImage == nil, let raw = track.artworkUrl, let url = URL(string: raw),
              ["https", "http"].contains(url.scheme ?? "") else { return }
        let key = track.identity + raw
        guard artworkKey != key else { return }
        artworkTask?.cancel(); artworkKey = key
        if let cached = artworkCache.object(forKey: raw as NSString) { currentTrack?.artworkImage = cached; artworkColor = ArtworkPalette.color(from: cached); return }
        artworkTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            guard let data, data.count < 8_000_000, let image = NSImage(data: data),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            DispatchQueue.main.async {
                guard let self, self.currentTrack?.identity == track.identity else { return }
                self.artworkCache.setObject(image, forKey: raw as NSString)
                self.currentTrack?.artworkImage = image
                self.artworkColor = ArtworkPalette.color(from: image)
            }
        }
        artworkTask?.resume()
    }
    public func togglePlayPause() { send(nativeCommand: "playpause", browserAction: "togglePlayPause") }
    public func nextTrack() { guard currentTrack?.canSkip == true else { return }; send(nativeCommand: "next track", browserAction: "next") }
    public func previousTrack() { guard currentTrack?.canSkip == true else { return }; send(nativeCommand: "previous track", browserAction: "previous") }
    public func seek(to position: TimeInterval) {
        guard let track = currentTrack, track.canSeek, position.isFinite else { return }
        let target = min(max(position,0), track.duration)
        send(nativeCommand: "set player position to \(target)", browserAction: "seek", value: target)
    }
    func toggleShuffle() {
        guard let track = currentTrack, let shuffle = track.shuffle else { return }
        send(nativeCommand: "set \(track.playerType == .appleMusic ? "shuffle enabled" : "shuffling") to \(!shuffle)", browserAction: "shuffle")
    }
    private func send(nativeCommand: String, browserAction: String, value: Double? = nil) {
        guard let track = currentTrack, !commandPending else { return }
        commandGeneration += 1
        commandPending = true; errorMessage = nil
        let completion: (String?) -> Void = { [weak self] error in
            guard let self else { return }
            self.commandPending = false; self.errorMessage = error
            if error == nil { self.pollCurrentPlayer() }
        }
        if track.playerType == .browser {
            WebSocketBridgeService.shared.sendCommand(sourceID: track.sourceID, action: browserAction, value: value, completion: completion)
        } else { native.command(nativeCommand, type: track.playerType, completion: completion) }
    }
    func openCurrentSource() {
        guard let track = currentTrack else { return }
        if track.playerType == .browser {
            WebSocketBridgeService.shared.sendCommand(sourceID: track.sourceID, action: "activate", completion: { [weak self] in self?.errorMessage = $0 })
        } else if let id = NativeMediaClient.bundleID(track.playerType), let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }
}
