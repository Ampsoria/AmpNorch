import Foundation

struct NotchActivity: Identifiable, Equatable {
    enum Kind: Equatable { case headphones, airPodsCase, charging, volume, capsLock, recognition }
    let id = UUID()
    let kind: Kind
    let title: String
    let subtitle: String
    let symbol: String
    var progress: Double? = nil
}

/// Pure transition model: repeated system callbacks must not produce repeated banners.
struct ConnectionTracker {
    private(set) var connected = Set<String>()

    mutating func seed(_ addresses: Set<String>) { connected = addresses }
    mutating func connect(_ address: String) -> Bool { connected.insert(address).inserted }
    mutating func disconnect(_ address: String) { connected.remove(address) }
}
