import AppKit
import AVFoundation
import CoreBluetooth
import Carbon
import Combine

final class SetupPermissionsService: ObservableObject {
    @Published private(set) var musicStatus = "Checking…"
    @Published private(set) var spotifyStatus = "Checking…"
    @Published private(set) var microphoneStatus = "Not requested"
    @Published private(set) var requesting: PlayerType?
    private let queue = DispatchQueue(label: "com.ampsoria.permission-requests")
    private var refreshGeneration = 0

    func refresh() {
        microphoneStatus = Self.microphoneDescription
        guard requesting == nil else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        let players: [(PlayerType, String, Bool, Bool)] = [PlayerType.appleMusic, .spotify].map { type in
            let id = NativeMediaClient.bundleID(type)!
            return (type, id, NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil,
                    !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty)
        }
        queue.async { [weak self] in
            let statuses = players.map { type, id, installed, running in
                (type, !installed ? "Not installed" : !running ? "Click Connect to open the app and request access" :
                    Self.automationDescription(NativeMediaClient.automationPermission(bundleID: id, request: false)))
            }
            DispatchQueue.main.async {
                guard let self, self.refreshGeneration == generation, self.requesting == nil else { return }
                for (type, status) in statuses { self.setStatus(status, for: type) }
            }
        }
    }

    func connect(_ player: PlayerType) {
        guard requesting == nil, let id = NativeMediaClient.bundleID(player) else { return }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            setStatus("This app is not installed", for: player); return
        }
        requesting = player; refreshGeneration += 1
        setStatus("Waiting for macOS permission…", for: player)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] app, error in
            guard let self else { return }
            guard app != nil, error == nil else {
                DispatchQueue.main.async {
                    self.requesting = nil; self.setStatus("Could not open the player. Open it, then try again.", for: player)
                }; return
            }
            self.queue.async {
                let result = NativeMediaClient.automationPermission(bundleID: id, request: true)
                DispatchQueue.main.async {
                    self.requesting = nil
                    self.setStatus(Self.automationDescription(result), for: player)
                    if result == noErr { MusicPlayerService.shared.pollCurrentPlayer() }
                }
            }
        }
    }

    func requestMicrophone() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .denied || AVCaptureDevice.authorizationStatus(for: .audio) == .restricted {
            Self.openPrivacy("Privacy_Microphone"); return
        }
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            DispatchQueue.main.async { self?.microphoneStatus = Self.microphoneDescription }
        }
    }

    func enableBluetooth() {
        if CBManager.authorization == .denied || CBManager.authorization == .restricted {
            Self.openPrivacy("Privacy_Bluetooth")
        } else { AirPodsProximityService.shared.enabled = true }
    }

    func enableWaveform() {
        let audio = AudioMeterService.shared
        if audio.enabled { audio.stop(); audio.start() }
        else { audio.enabled = true }
    }

    static func openPrivacy(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        if !NSWorkspace.shared.open(url), let fallback = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension") {
            NSWorkspace.shared.open(fallback)
        }
    }

    private func setStatus(_ status: String, for type: PlayerType) {
        if type == .appleMusic { musicStatus = status } else { spotifyStatus = status }
    }
    private static func automationDescription(_ status: OSStatus) -> String {
        switch status {
        case noErr: return "Access allowed — play a song to show it in the notch"
        case OSStatus(errAEEventWouldRequireUserConsent): return "Not requested — click Connect to allow access"
        case OSStatus(errAEEventNotPermitted): return "Access denied — enable AmpNotch in Automation settings"
        case OSStatus(procNotFound): return "Open the player, then click Connect"
        default: return "Could not check access (\(status)); try Connect again"
        }
    }
    private static var microphoneDescription: String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return "Access allowed — used only when you identify a song"
        case .denied: return "Access denied — enable AmpNotch in Microphone settings"
        case .restricted: return "Microphone access is restricted on this Mac"
        case .notDetermined: return "Not requested"
        @unknown default: return "Microphone status unavailable"
        }
    }
}
