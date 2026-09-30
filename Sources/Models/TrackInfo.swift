import Foundation
import AppKit

public enum PlayerType: String, Codable {
    case appleMusic = "Apple Music", spotify = "Spotify", browser = "Browser", none = "None"
    public var iconName: String {
        switch self {
        case .appleMusic: return "music.note"
        case .spotify: return "antenna.radiowaves.left.and.right"
        case .browser: return "globe"
        case .none: return "music.note"
        }
    }
}

public struct TrackInfo: Equatable {
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval
    public var position: TimeInterval
    public var isPlaying: Bool
    public var playerType: PlayerType
    public var artworkImage: NSImage?
    public var artworkUrl: String?
    public var sourceID: String
    public var mediaID: String
    public var canSeek: Bool
    public var canSkip: Bool
    public var shuffle: Bool?
    public var identity: String { sourceID + ":" + mediaID }

    public init(title: String, artist: String, album: String, duration: TimeInterval,
                position: TimeInterval, isPlaying: Bool, playerType: PlayerType,
                artworkImage: NSImage? = nil, artworkUrl: String? = nil,
                sourceID: String? = nil, mediaID: String? = nil,
                canSeek: Bool = true, canSkip: Bool = true, shuffle: Bool? = nil) {
        self.title = title; self.artist = artist; self.album = album
        self.duration = duration.isFinite ? max(duration, 0) : 0
        self.position = position.isFinite ? max(0, position) : 0
        if self.duration > 0 { self.position = min(self.position, self.duration) }
        self.isPlaying = isPlaying; self.playerType = playerType
        self.artworkImage = artworkImage; self.artworkUrl = artworkUrl
        self.sourceID = sourceID ?? playerType.rawValue
        self.mediaID = mediaID ?? title + ":" + artist + ":" + album
        self.canSeek = canSeek && self.duration > 0
        self.canSkip = canSkip; self.shuffle = shuffle
    }
    public static func == (a: TrackInfo, b: TrackInfo) -> Bool {
        a.identity == b.identity && a.position == b.position && a.isPlaying == b.isPlaying &&
        a.duration == b.duration && a.shuffle == b.shuffle && a.artworkImage === b.artworkImage
    }
    public var formattedPosition: String { Self.formatTime(position) }
    public var formattedDuration: String { duration > 0 ? Self.formatTime(duration) : "LIVE" }
    public var formattedRemaining: String { duration > 0 ? "-" + Self.formatTime(max(duration-position,0)) : "LIVE" }
    public var progress: Double { duration > 0 ? min(max(position/duration,0),1) : 0 }
    private static func formatTime(_ value: Double) -> String {
        guard value.isFinite else { return "0:00" }
        let seconds = Int(min(max(value,0), 359999))
        return String(format: "%d:%02d", seconds/60, seconds%60)
    }
}

/// Keep the last actively started source. A paused app cannot override a playing source.
struct MediaSourceSelection {
    private(set) var tracks: [String: TrackInfo] = [:]
    private var activation: [String: Int] = [:]
    private var sequence = 0
    var preferredSource: String?
    mutating func update(_ track: TrackInfo) {
        if track.isPlaying && (tracks[track.sourceID]?.isPlaying != true || tracks[track.sourceID]?.identity != track.identity) {
            sequence += 1; activation[track.sourceID] = sequence
        }
        tracks[track.sourceID] = track
    }
    mutating func remove(_ source: String) {
        tracks.removeValue(forKey: source); activation.removeValue(forKey: source)
        if preferredSource == source { preferredSource = nil }
    }
    var selected: TrackInfo? {
        if let preferredSource, let track = tracks[preferredSource] { return track }
        return tracks.values.sorted {
            if $0.isPlaying != $1.isPlaying { return $0.isPlaying }
            let left = activation[$0.sourceID, default: 0], right = activation[$1.sourceID, default: 0]
            return left == right ? $0.sourceID < $1.sourceID : left > right
        }.first
    }
}
