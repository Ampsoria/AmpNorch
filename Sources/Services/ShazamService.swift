import Foundation
import ShazamKit
import AVFoundation
import Combine

public class ShazamService: NSObject, ObservableObject, SHSessionDelegate {
    public static let shared = ShazamService()
    
    @Published public var isListening: Bool = false
    @Published public var matchResult: String? = nil
    @Published public var errorMessage: String? = nil
    
    private var timeout: DispatchWorkItem?
    private var session: SHSession?
    private var audioEngine = AVAudioEngine()
    
    public override init() {
        super.init()
        session = SHSession()
        session?.delegate = self
    }
    
    public func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    public func startListening() {
        guard !isListening else { return }
        
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                DispatchQueue.main.async {
                    self.errorMessage = "Microphone access denied"
                }
                return
            }
            
            DispatchQueue.main.async {
                self.runAudioEngine()
            }
        }
    }
    
    private func runAudioEngine() {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            errorMessage = "No microphone input is available."; return
        }
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: recordingFormat) { [weak self] buffer, time in
            self?.session?.matchStreamingBuffer(buffer, at: time)
        }
        
        do {
            try audioEngine.start()
            isListening = true
            matchResult = nil
            errorMessage = nil
            
            timeout?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.isListening else { return }
                self.stopListening()
                if self.matchResult == nil { self.matchResult = "No match found" }
            }
            timeout = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: work)

        } catch {
            audioEngine.inputNode.removeTap(onBus: 0)
            isListening = false
            errorMessage = "Could not start audio engine: \(error.localizedDescription)"
        }
    }
    
    public func stopListening() {
        timeout?.cancel()
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isListening = false
    }
    
    // MARK: - SHSessionDelegate
    public func session(_ session: SHSession, didFind match: SHMatch) {
        guard let mediaItem = match.mediaItems.first else { return }
        
        DispatchQueue.main.async {
            self.stopListening()
            let title = mediaItem.title ?? "Unknown Title"
            let artist = mediaItem.artist ?? "Unknown Artist"
            self.matchResult = "\(title) • \(artist)"
            
            NotchPresentationService.shared.present(NotchActivity(kind: .recognition,
                title: title, subtitle: artist, symbol: "shazam.logo.fill"), duration: 6)

        }
    }
    
    public func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        DispatchQueue.main.async {
            self.stopListening()
            self.matchResult = error == nil ? "No song identified" : nil
            self.errorMessage = error?.localizedDescription
        }
    }
}
