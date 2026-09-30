import AppKit
import CoreAudio
import Combine

final class AudioMeterService: ObservableObject {
    static let shared = AudioMeterService()
    @Published private(set) var levels = [Double](repeating: 0, count: 6)
    @Published private(set) var status = "Audio waveform is off"
    @Published var enabled = UserDefaults.standard.object(forKey: "audioReactiveWaveform") as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "audioReactiveWaveform")
            if enabled { start() } else { stop(); status = "Audio waveform is off" }
        }
    }
    private var tap: AudioObjectID = 0
    private var aggregate: AudioObjectID = 0
    private var ioProc: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "com.ampsoria.audio-meter", qos: .userInitiated)
    // Core Audio device startup may wait indefinitely on a driver/permission
    // response. Never perform hardware lifecycle work on the AppKit thread.
    private let hardwareQueue = DispatchQueue(label: "com.ampsoria.audio-meter.lifecycle")
    private var startRequested = false // main-thread only
    private let dsp = WaveformDSP()
    private var subscriptions = Set<AnyCancellable>()
    private var lastPublish = Date.distantPast
    private var collected: [Float] = []
    private var generation = 0
    private var outputListener: AudioObjectPropertyListenerBlock?
    init() {
        MusicPlayerService.shared.$currentTrack.map { $0?.isPlaying == true }.removeDuplicates().sink { [weak self] playing in
            if !playing { self?.levels = Array(repeating: 0, count: 6) }
        }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in self?.stop() }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in if self?.enabled == true { self?.start() } }.store(in: &subscriptions)
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self, self.enabled else { return }
            self.stop()
            self.start()
        }
        outputListener = listener
        var outputAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &outputAddress, .main, listener)
        if enabled { start() }
    }
    func start() {
        guard enabled, !startRequested else { return }
        guard #available(macOS 14.2, *) else { status = "Live audio requires macOS 14.2 or later"; return }
        startRequested = true
        generation += 1
        let session = generation
        status = "Starting system audio…"
        hardwareQueue.async { [weak self] in self?.startCapture(session: session) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.generation == session, self.status == "Starting system audio…" else { return }
            self.status = "System audio is taking longer to respond; playback controls remain available."
        }
    }
    private func startCapture(session: Int) {
        guard #available(macOS 14.2, *), tap == 0 else { return }
        let description = CATapDescription(monoGlobalTapButExcludeProcesses: [])
        description.name = "AmpNotch waveform"
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = .unmuted
        var result = AudioHardwareCreateProcessTap(description, &tap)
        guard result == noErr else { fail("Cannot access system audio", result, session: session); return }
        var format = AudioStreamBasicDescription()
        var address = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        result = AudioObjectGetPropertyData(tap, &address, 0, nil, &size, &format)
        guard result == noErr, format.mBitsPerChannel == 32, format.mFormatFlags & kAudioFormatFlagIsFloat != 0 else {
            fail("Unsupported system audio format", result, session: session); return
        }
        // The tap needs the output device's clock to deliver samples reliably.
        var output: AudioObjectID = 0
        address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        size = UInt32(MemoryLayout<AudioObjectID>.size)
        result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &output)
        guard result == noErr, output != 0 else { fail("No audio output available", result, session: session); return }
        var rawUID: Unmanaged<CFString>?
        address.mSelector = kAudioDevicePropertyDeviceUID
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        result = AudioObjectGetPropertyData(output, &address, 0, nil, &size, &rawUID)
        guard result == noErr, let rawUID else { fail("Cannot read audio output", result, session: session); return }
        let outputUID = rawUID.takeUnretainedValue()
        let spec: [String: Any] = [kAudioAggregateDeviceNameKey: "AmpNotch Meter",
            kAudioAggregateDeviceUIDKey: UUID().uuidString, kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: description.uuid.uuidString, kAudioSubTapDriftCompensationKey: true]]]
        result = AudioHardwareCreateAggregateDevice(spec as CFDictionary, &aggregate)
        guard result == noErr else { fail("Cannot create audio meter", result, session: session); return }
        let sampleRate = format.mSampleRate
        result = AudioDeviceCreateIOProcIDWithBlock(&ioProc, aggregate, queue) { [weak self] _, input, _, _, _ in
            guard let self else { return }
            let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
            guard let buffer = buffers.first, let data = buffer.mData, buffer.mDataByteSize > 0 else { return }
            let samples = data.assumingMemoryBound(to: Float.self)
            let channels = max(1, Int(buffer.mNumberChannels))
            let length = Int(buffer.mDataByteSize)/MemoryLayout<Float>.size
            for offset in stride(from: 0, to: length, by: channels) { self.collected.append(samples[offset]) }
            guard self.collected.count >= 1024 else { return }
            let chunk = Array(self.collected.suffix(1024))
            self.collected.removeAll(keepingCapacity: true)
            let now = Date()
            guard now.timeIntervalSince(self.lastPublish) >= 1.0/30 else { return }
            self.lastPublish = now
            let measured = self.dsp.levels(samples: chunk, sampleRate: sampleRate)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.enabled, self.generation == session else { return }
                if MusicPlayerService.shared.currentTrack?.isPlaying == true {
                    self.levels = zip(self.levels, measured).map { old, new in old*0.25 + new*0.75 }
                } else { self.levels = Array(repeating: 0, count: 6) }
                self.status = "Reading system audio · nothing is recorded or uploaded"
            }
        }
        guard result == noErr else { fail("Cannot start audio meter", result, session: session); return }
        result = AudioDeviceStart(aggregate, ioProc)
        guard result == noErr else { fail("Allow system audio recording in Privacy & Security", result, session: session); return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == session else { return }
            if !self.status.hasPrefix("Reading") { self.status = "Waiting for system audio permission / playback" }
        }
    }
    private func fail(_ message: String, _ code: OSStatus, session: Int) {
        stopCapture()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == session else { return }
            self.startRequested = false
            self.status = "\(message) (\(code))"
        }
    }
    func stop() {
        generation += 1
        startRequested = false
        levels = Array(repeating: 0, count: 6)
        hardwareQueue.async { [weak self] in self?.stopCapture() }
    }
    private func stopCapture() {
        if aggregate != 0 {
            if let ioProc { AudioDeviceStop(aggregate, ioProc); AudioDeviceDestroyIOProcID(aggregate, ioProc) }
            AudioHardwareDestroyAggregateDevice(aggregate)
        }
        if #available(macOS 14.2, *), tap != 0 { AudioHardwareDestroyProcessTap(tap) }
        ioProc = nil; aggregate = 0; tap = 0
        queue.sync { collected.removeAll(); lastPublish = .distantPast }
    }
}
