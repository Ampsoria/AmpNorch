import AppKit
import CoreAudio
import Combine

final class SystemHUDService {
    static let shared = SystemHUDService()
    private var subscriptions = Set<AnyCancellable>()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var capsLock = NSEvent.modifierFlags.contains(.capsLock)
    private var outputDevice = AudioDeviceID(0)
    private var volumeElements: [AudioObjectPropertyElement] = []
    private var lastVolume: Float32?
    private var lastMuted: UInt32?
    private var audioListeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    init() {
        BatteryService.shared.$isCharging.removeDuplicates().dropFirst().sink { charging in
            guard charging, UserDefaults.standard.object(forKey: "showBatteryHUD") as? Bool != false else { return }
            let level = BatteryService.shared.batteryLevel
            NotchPresentationService.shared.present(NotchActivity(kind: .charging, title: "Charging",
                subtitle: "MacBook · \(level)%", symbol: "battery.100.bolt", progress: Double(level) / 100))
        }.store(in: &subscriptions)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.updateCapsLock(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.updateCapsLock(event)
            return event
        }
        configureAudio()
    }

    private func updateCapsLock(_ event: NSEvent) {
        let enabled = event.modifierFlags.contains(.capsLock)
        guard capsLock != enabled else { return }
        capsLock = enabled
        guard UserDefaults.standard.object(forKey: "showCapsLockHUD") as? Bool != false else { return }
        NotchPresentationService.shared.present(NotchActivity(kind: .capsLock, title: "Caps Lock",
            subtitle: enabled ? "On" : "Off", symbol: enabled ? "capslock.fill" : "capslock"), duration: 2)
    }

    private func configureAudio() {
        removeAudioListeners()
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        outputDevice = 0
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &outputDevice)
        listen(AudioObjectID(kAudioObjectSystemObject), address) { [weak self] in self?.configureAudio() }
        lastVolume = nil
        lastMuted = nil
        guard outputDevice != 0 else { return }
        volumeElements = [0, 1, 2].filter { element in
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput, mElement: AudioObjectPropertyElement(element))
            return AudioObjectHasProperty(outputDevice, &address)
        }
        if volumeElements.contains(0) { volumeElements = [0] }
        for element in volumeElements {
            let property = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            listen(outputDevice, property) { [weak self] in self?.readVolume(showHUD: true) }
        }
        listen(outputDevice, AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)) {
            [weak self] in self?.readVolume(showHUD: true)
        }
        readVolume(showHUD: false)
    }

    private func listen(_ object: AudioObjectID, _ property: AudioObjectPropertyAddress, action: @escaping () -> Void) {
        var address = property
        guard AudioObjectHasProperty(object, &address) else { return }
        let block: AudioObjectPropertyListenerBlock = { _, _ in action() }
        if AudioObjectAddPropertyListenerBlock(object, &address, .main, block) == noErr {
            audioListeners.append((object, property, block))
        }
    }

    private func readVolume(showHUD: Bool) {
        let values: [Float32] = volumeElements.compactMap { element in
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            guard AudioObjectGetPropertyData(outputDevice, &address, 0, nil, &size, &value) == noErr else { return nil }
            return value
        }
        guard !values.isEmpty else { return } // HDMI/fixed-volume routes may not expose volume.
        let volume = values.reduce(0, +) / Float32(values.count)
        var muted: UInt32 = 0
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(outputDevice, &address, 0, nil, &size, &muted)
        let changed = lastVolume != volume || lastMuted != muted
        lastVolume = volume
        lastMuted = muted
        guard showHUD && changed, UserDefaults.standard.object(forKey: "showVolumeHUD") as? Bool != false else { return }
        // A route change can alter volume while AirPods are connecting. Keep the connection visible.
        guard NotchPresentationService.shared.activity?.kind != .headphones else { return }
        let percent = Int(min(max(volume, 0), 1) * 100)
        NotchPresentationService.shared.present(NotchActivity(kind: .volume, title: "Volume",
            subtitle: muted != 0 ? "Muted" : "\(percent)%",
            symbol: muted != 0 || percent == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill",
            progress: muted != 0 ? 0 : Double(volume)), duration: 1.8)
    }

    private func removeAudioListeners() {
        for (object, property, block) in audioListeners {
            var address = property
            AudioObjectRemovePropertyListenerBlock(object, &address, .main, block)
        }
        audioListeners.removeAll()
    }

    deinit {
        removeAudioListeners()
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }
}
