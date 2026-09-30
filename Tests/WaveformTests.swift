import AppKit
import Foundation

@main
struct WaveformTests {
    static func main() {
        let dsp = WaveformDSP()
        precondition(dsp.levels(samples: Array(repeating: 0, count: 1024), sampleRate: 48000).allSatisfy { $0 == 0 })
        let signal = (0..<1024).map { Float(0.4 * sin(2 * Double.pi * 1000 * Double($0) / 48000)) }
        let bands = dsp.levels(samples: signal, sampleRate: 48000)
        precondition(bands[2] > 0.5 && bands[2] > bands[0] && bands[2] > bands[5], "A real 1 kHz signal must energize its measured band")
        let red = NSImage(size: NSSize(width: 24, height: 24))
        red.lockFocus(); NSColor.red.setFill(); NSRect(x: 0, y: 0, width: 24, height: 24).fill(); red.unlockFocus()
        let color = ArtworkPalette.color(from: red).usingColorSpace(.deviceRGB)!
        precondition(color.redComponent > color.greenComponent && color.redComponent > color.blueComponent, "Waveform tint must follow the cover")
        precondition(ArtworkPalette.color(from: nil).alphaComponent == 1)
        print("PASS: silence, measured sine-wave spectrum and artwork-derived color")
    }
}
