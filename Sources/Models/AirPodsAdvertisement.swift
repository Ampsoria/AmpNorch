import Foundation

/// Clean-room decoder of the published Apple proximity (0x07/0x19) wire layout.
/// References and limits are recorded in INTEGRATIONS.md. Unknown packets are ignored.
struct AirPodsAdvertisement: Equatable {
    let model: UInt16
    let firstBattery: Int?
    let secondBattery: Int?
    let caseBattery: Int?
    let caseOpen: Bool
    let lidCounter: UInt8
    var modelName: String {
        switch model {
        case 0x0220: return "AirPods"
        case 0x0f20: return "AirPods 2"
        case 0x1320: return "AirPods 3"
        case 0x1920: return "AirPods 4"
        case 0x1b20: return "AirPods 4 (ANC)"
        case 0x0e20: return "AirPods Pro"
        case 0x1420, 0x2420: return "AirPods Pro 2"
        case 0x2720: return "AirPods Pro 3"
        case 0x0a20, 0x1f20: return "AirPods Max"
        default: return "Apple headphones"
        }
    }
    var symbol: String { modelName.contains("Max") ? "airpodsmax" : modelName.contains("Pro") ? "airpodspro" : "airpods" }
    var batterySummary: String {
        let values = [firstBattery, secondBattery].compactMap { $0 }.sorted()
        var parts: [String] = []
        if let low = values.first, let high = values.last {
            parts.append(low == high ? "Earbuds ≈\(low)%" : "Earbuds ≈\(low)–\(high)%")
        }
        if let caseBattery { parts.append("Case ≈\(caseBattery)%") }
        return parts.isEmpty ? "Nearby · battery unavailable" : parts.joined(separator: " · ")
    }
    init?(manufacturerData: Data) {
        let bytes = [UInt8](manufacturerData)
        guard bytes.count >= 29, bytes[0] == 0x4c, bytes[1] == 0,
              bytes[2] == 7, bytes[3] == 25, bytes[4] == 1 else { return nil }
        let model = UInt16(bytes[5]) << 8 | UInt16(bytes[6])
        guard [0x0220, 0x0f20, 0x1320, 0x1920, 0x1b20, 0x0e20, 0x1420, 0x2420, 0x2720, 0x0a20, 0x1f20].contains(Int(model)) else { return nil }
        self.model = model
        func battery(_ nibble: UInt8) -> Int? { nibble <= 10 ? Int(nibble) * 10 : nil }
        firstBattery = battery(bytes[8] & 15)
        secondBattery = battery(bytes[8] >> 4)
        caseBattery = battery(bytes[9] & 15)
        // No lid state is claimed when neither pod is in the case (or for AirPods Max).
        caseOpen = bytes[10] & 8 != 0 && bytes[7] & 0x14 != 0 && ![0x0a20, 0x1f20].contains(Int(model))
        lidCounter = bytes[10] & 7
    }
}

struct AirPodsLidTracker {
    private var states: [UUID: (open: Bool, counter: UInt8, seen: Date, shown: Date?, shownCounter: UInt8?)] = [:]
    mutating func observe(id: UUID, packet: AirPodsAdvertisement, rssi: Int, now: Date = Date()) -> Bool {
        states = states.filter { now.timeIntervalSince($0.value.seen) < 300 }
        let previous = states[id]
        let opening = packet.caseOpen && (previous?.open != true || previous?.counter != packet.lidCounter || previous?.shownCounter != packet.lidCounter)
        let cooldownPassed = previous?.shown.map { now.timeIntervalSince($0) >= 5 } ?? true
        let announce = opening && (-65 ... -1).contains(rssi) && cooldownPassed
        states[id] = (packet.caseOpen, packet.lidCounter, now, announce ? now : previous?.shown,
                      !packet.caseOpen ? nil : announce ? packet.lidCounter : previous?.shownCounter)
        return announce
    }
}
