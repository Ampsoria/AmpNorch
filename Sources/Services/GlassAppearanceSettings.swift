import Foundation
import Combine

final class GlassAppearanceSettings: ObservableObject {
    static let shared = GlassAppearanceSettings()
    static let defaultOpacity = 0.62
    static let opacityRange = 0.2...1.0

    @Published var notchOpacity: Double {
        didSet { defaults.set(Self.validOpacity(notchOpacity), forKey: "notchGlassOpacity") }
    }
    @Published var lockScreenOpacity: Double {
        didSet { defaults.set(Self.validOpacity(lockScreenOpacity), forKey: "lockScreenGlassOpacity") }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        notchOpacity = Self.validOpacity(defaults.object(forKey: "notchGlassOpacity") as? Double ?? Self.defaultOpacity)
        lockScreenOpacity = Self.validOpacity(defaults.object(forKey: "lockScreenGlassOpacity") as? Double ?? Self.defaultOpacity)
    }

    func restoreDefaults() {
        notchOpacity = Self.defaultOpacity
        lockScreenOpacity = Self.defaultOpacity
    }

    static func validOpacity(_ value: Double) -> Double {
        value.isFinite ? min(max(value, opacityRange.lowerBound), opacityRange.upperBound) : defaultOpacity
    }
}
