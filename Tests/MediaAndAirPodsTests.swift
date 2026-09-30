import AppKit
import Foundation

@main
struct MediaAndAirPodsTests {
    static func track(_ source: String, _ playing: Bool, _ title: String = "Track", position: Double = 0) -> TrackInfo {
        TrackInfo(title: title, artist: "Artist", album: "Album", duration: 200,
                  position: position, isPlaying: playing, playerType: source == "web" ? .browser : .appleMusic, sourceID: source)
    }
    static func main() {
        var selection = MediaSourceSelection()
        selection.update(track("music", false))
        selection.update(track("web", true))
        selection.update(track("music", false, position: 22))
        precondition(selection.selected?.sourceID == "web", "Paused Music must not steal playing browser media")
        selection.update(track("spotify", true))
        selection.update(track("web", true, position: 15))
        precondition(selection.selected?.sourceID == "spotify", "Heartbeats must not steal from a newly started source")
        selection.update(track("spotify", false))
        precondition(selection.selected?.sourceID == "web", "Resume selection of a still-playing source")
        selection.preferredSource = "music"
        precondition(selection.selected?.sourceID == "music", "Explicit source selection must win")
        selection.remove("music")
        precondition(selection.selected?.sourceID == "web", "Closing selected source must restore automatic selection")
        selection.remove("web"); selection.remove("spotify")
        precondition(selection.selected == nil, "Closed media must clear, not leave a demo or stale track")
        let invalid = TrackInfo(title: "Live", artist: "", album: "", duration: .infinity, position: .nan,
                                isPlaying: true, playerType: .browser)
        precondition(invalid.duration == 0 && invalid.position == 0 && !invalid.canSeek && invalid.formattedRemaining == "LIVE")
        let lyrics = LyricsData.parseLRC("[00:02.5]First\n[00:03.25][00:05.750]Repeat")
        precondition(lyrics.lines.map(\.time) == [2.5, 3.25, 5.75])
        precondition(lyrics.activeIndex(for: 1) == nil && lyrics.activeIndex(for: 4) == 1)

        // Synthetic protocol fixtures, not a claim of hardware validation.
        var bytes: [UInt8] = [0x4c,0,7,25,1,0x0e,0x20,0x14,0x87,0x46,0x09,0,0] + Array(repeating: 0, count: 16)
        let open = AirPodsAdvertisement(manufacturerData: Data(bytes))!
        precondition(open.modelName == "AirPods Pro" && open.caseOpen)
        precondition(open.firstBattery == 70 && open.secondBattery == 80 && open.caseBattery == 60)
        precondition(AirPodsAdvertisement(manufacturerData: Data(bytes.prefix(12))) == nil)
        bytes[0] = 0
        precondition(AirPodsAdvertisement(manufacturerData: Data(bytes)) == nil)
        bytes[0] = 0x4c; bytes[8] = 0xff; bytes[9] = 0xff
        let unknown = AirPodsAdvertisement(manufacturerData: Data(bytes))!
        precondition(unknown.firstBattery == nil && unknown.caseBattery == nil, "Unknown battery must not appear as 100%")
        bytes[5] = 0x0a; bytes[6] = 0x20
        precondition(AirPodsAdvertisement(manufacturerData: Data(bytes))?.caseOpen == false, "AirPods Max has no case lid")
        bytes[5] = 0x0e; bytes[10] = 1
        let closed = AirPodsAdvertisement(manufacturerData: Data(bytes))!
        let id = UUID(), now = Date()
        var tracker = AirPodsLidTracker()
        precondition(!tracker.observe(id: id, packet: open, rssi: -90, now: now))
        precondition(tracker.observe(id: id, packet: open, rssi: -40, now: now.addingTimeInterval(1)))
        precondition(!tracker.observe(id: id, packet: open, rssi: -40, now: now.addingTimeInterval(2)))
        precondition(!tracker.observe(id: id, packet: closed, rssi: -40, now: now.addingTimeInterval(3)))
        precondition(tracker.observe(id: id, packet: open, rssi: -40, now: now.addingTimeInterval(8)))
        print("PASS: active media arbitration, close/pin behavior, live/nonfinite timing, real lyric timing, BLE bounds/model/battery/lid transitions")
    }
}
