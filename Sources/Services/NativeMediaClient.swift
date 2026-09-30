import AppKit
import Carbon

struct NativeMediaResult {
    let type: PlayerType
    let track: TrackInfo?
    let error: String?
}

/// All Apple Events are serialized; typed AppleScript lists preserve punctuation/newlines.
final class NativeMediaClient {
    private var artworkCache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "com.ampsoria.media-events", qos: .userInitiated)
    private var accessChecks: [String: (date: Date, result: OSStatus)] = [:]

    /// Call on a worker queue. Checking never prompts; only the setup button
    /// passes true, after making sure the destination app is running.
    static func automationPermission(bundleID: String, request: Bool) -> OSStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        guard let descriptor = target.aeDesc else { return OSStatus(paramErr) }
        return AEDeterminePermissionToAutomateTarget(descriptor, typeWildCard, typeWildCard, request)
    }
    static func bundleID(_ type: PlayerType) -> String? {
        switch type {
        case .appleMusic: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        default: return nil
        }
    }
    func poll(completion: @escaping ([NativeMediaResult]) -> Void) {
        let running = [PlayerType.appleMusic, .spotify].filter {
            !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID($0)!).isEmpty
        }
        queue.async {
            let results = [PlayerType.appleMusic, .spotify].map { type -> NativeMediaResult in
                guard running.contains(type) else { return NativeMediaResult(type: type, track: nil, error: nil) }
                let bundleID = Self.bundleID(type)!
                let permission: OSStatus
                if let cached = self.accessChecks[bundleID], Date().timeIntervalSince(cached.date) < 5 {
                    permission = cached.result
                } else {
                    permission = Self.automationPermission(bundleID: bundleID, request: false)
                    self.accessChecks[bundleID] = (Date(), permission)
                }
                guard permission == noErr else {
                    return NativeMediaResult(type: type, track: nil,
                        error: "Connect \(type.rawValue) in Settings → Setup & permissions to allow playback access.")
                }
                let music = type == .appleMusic
                let script = """
                with timeout of 2 seconds
                    tell application id "\(Self.bundleID(type)!)"
                        if player state is stopped then return {}
                        set t to current track
                        set imageValue to ""
                        try
                            \(music ? "set imageValue to raw data of artwork 1 of t" : "set imageValue to artwork url of t")
                        end try
                        set shuffleValue to false
                        try
                            set shuffleValue to \(music ? "shuffle enabled" : "shuffling")
                        end try
                        return {\(music ? "persistent ID" : "id") of t, name of t, artist of t, album of t, duration of t, player position, player state is playing, shuffleValue, imageValue}
                    end tell
                end timeout
                """
                let (value, error) = Self.execute(script)
                guard let value, value.numberOfItems >= 8 else { return NativeMediaResult(type: type, track: nil, error: error) }
                let number: (Int) -> Double = { value.atIndex($0)?.doubleValue ?? 0 }
                let identity = value.atIndex(1)?.stringValue ?? ""
                var artwork = self.artworkCache[identity]
                if artwork == nil && music {
                    artwork = value.atIndex(9).flatMap { NSImage(data: $0.data) }
                    if let artwork {
                        if self.artworkCache.count >= 40 { self.artworkCache.removeAll() }
                        self.artworkCache[identity] = artwork
                    }
                }
                let track = TrackInfo(title: value.atIndex(2)?.stringValue ?? "", artist: value.atIndex(3)?.stringValue ?? "",
                    album: value.atIndex(4)?.stringValue ?? "", duration: number(5) / (music ? 1 : 1000),
                    position: number(6), isPlaying: value.atIndex(7)?.booleanValue ?? false, playerType: type,
                    artworkImage: artwork, artworkUrl: music ? nil : value.atIndex(9)?.stringValue,
                    mediaID: value.atIndex(1)?.stringValue, shuffle: value.atIndex(8)?.booleanValue)
                return NativeMediaResult(type: type, track: track, error: error)
            }
            DispatchQueue.main.async { completion(results) }
        }
    }
    func command(_ command: String, type: PlayerType, completion: @escaping (String?) -> Void) {
        guard let bundle = Self.bundleID(type), !NSRunningApplication.runningApplications(withBundleIdentifier: bundle).isEmpty else {
            completion("The media app is no longer running."); return
        }
        queue.async {
            let (_, error) = Self.execute("with timeout of 2 seconds\ntell application id \"\(bundle)\" to \(command)\nend timeout")
            DispatchQueue.main.async { completion(error) }
        }
    }
    private static func execute(_ text: String) -> (NSAppleEventDescriptor?, String?) {
        var details: NSDictionary?
        guard let script = NSAppleScript(source: text) else { return (nil, "Could not create media command.") }
        let output = script.executeAndReturnError(&details)
        if let details {
            if (details[NSAppleScript.errorNumber] as? Int) == -1743 {
                return (nil, "Allow AmpNotch in System Settings → Privacy & Security → Automation, then retry.")
            }
            return (nil, details[NSAppleScript.errorMessage] as? String ?? "The media app did not respond.")
        }
        return (output, nil)
    }
}
