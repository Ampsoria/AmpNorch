import Accelerate
import Foundation

/// Six measured frequency envelopes. No random values or clock-driven pretend audio.
final class WaveformDSP {
    private let count = 1024
    private let transform: OpaquePointer?
    private var window = [Float](repeating: 0, count: 1024)
    init() {
        transform = vDSP_DFT_zop_CreateSetup(nil, 1024, .FORWARD)
        vDSP_hann_window(&window, 1024, Int32(vDSP_HANN_NORM))
    }
    deinit { if let transform { vDSP_DFT_DestroySetup(transform) } }
    func levels(samples: [Float], sampleRate: Double) -> [Double] {
        guard let transform, samples.count >= count, sampleRate > 0 else { return Array(repeating: 0, count: 6) }
        var real = Array(samples.prefix(count)), imaginary = [Float](repeating: 0, count: count)
        var outReal = real, outImaginary = imaginary
        vDSP_vmul(real, 1, window, 1, &real, 1, vDSP_Length(count))
        vDSP_DFT_Execute(transform, &real, &imaginary, &outReal, &outImaginary)
        let edges = [60.0, 200, 500, 1200, 3000, 7000, 16000]
        return (0..<6).map { band in
            let start = max(1, Int(edges[band] * Double(count) / sampleRate))
            let end = min(count/2, Int(edges[band+1] * Double(count) / sampleRate))
            guard start < end else { return 0 }
            var energy: Double = 0
            for bin in start..<end { energy += Double(outReal[bin]*outReal[bin] + outImaginary[bin]*outImaginary[bin]) }
            let amplitude = sqrt(energy)/Double(count)
            return min(max((20*log10(max(amplitude,0.000001))+65)/55,0),1)
        }
    }
}
