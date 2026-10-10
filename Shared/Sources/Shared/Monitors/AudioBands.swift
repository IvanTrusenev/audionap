import Accelerate
import Foundation

/// Frequency bands of the system audio mix for the equalizer view.
/// Pure math: a Hann-windowed 2048-sample mono frame goes through a
/// radix-2 FFT, bin magnitudes group into 10 log-spaced bands, and the
/// bands normalize against their maximum so the UI reads 0…1.
public enum AudioBands {
    public static let bandCount = 10
    /// Floats per frame: the DSPSplitComplex variant of vDSP.FFT treats
    /// log2n as the log2 of the REAL sample count and produces N/2
    /// packed bins, so 4096 samples (log2n = 12) give ~23.4 Hz bins at
    /// 48 kHz.
    public static let frameSize = 4096

    /// Band edges in Hz: 11 edges delimit 10 bands from 60 Hz to 20 kHz.
    public static let bandEdges: [Double] =
        [60, 120, 250, 500, 1_000, 2_000, 4_000, 8_000, 12_000, 16_000, 20_000]

    /// Precomputed twiddle factors; shared across calls from a single
    /// capture queue — `nonisolated(unsafe)` is the same pattern as
    /// DaemonLoop.stop for state touched from one well-known context.
    private static nonisolated(unsafe) let fft: vDSP.FFT<DSPSplitComplex> = vDSP.FFT(
        log2n: vDSP_Length(12), radix: .radix2, ofType: DSPSplitComplex.self)!

    /// Computes the normalized band levels of one mono frame. Returns
    /// zeros for a frame of the wrong size.
    public static func compute(frame: [Float], sampleRate: Double) -> [Double] {
        guard frame.count == frameSize, sampleRate > 0 else {
            return Array(repeating: 0, count: bandCount)
        }

        // Hann window, computed inline — the vDSP.window API surface
        // churns between SDK versions, three lines are stabler.
        var window = [Float](repeating: 0, count: frameSize)
        for i in 0..<frameSize {
            window[i] = Float(0.5 * (1 - cos(2 * .pi * Double(i) / Double(frameSize - 1))))
        }
        var real = [Float](repeating: 0, count: frameSize)
        vDSP.multiply(frame, window, result: &real)
        var imag = [Float](repeating: 0, count: frameSize)
        real.withUnsafeMutableBufferPointer { realPointer in
            imag.withUnsafeMutableBufferPointer { imagPointer in
                var split = DSPSplitComplex(
                    realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
                fft.forward(input: split, output: &split)
            }
        }

        // Magnitudes of the packed output: N/2 bins.
        var magnitudes = [Double](repeating: 0, count: frameSize / 2)
        for bin in 0..<(frameSize / 2) {
            magnitudes[bin] = sqrt(
                Double(real[bin] * real[bin] + imag[bin] * imag[bin]))
        }

        // Group bins into log-spaced bands (average magnitude per band).
        // The packed output holds frameSize/2 bins, so the bin width is
        // sampleRate / (frameSize/2) — not sampleRate / frameSize.
        let binHz = sampleRate / Double(frameSize / 2)
        var bands = [Double](repeating: 0, count: bandCount)
        for band in 0..<bandCount {
            let lowBin = max(0, Int(bandEdges[band] / binHz))
            let highBin = min(frameSize / 2, Int(bandEdges[band + 1] / binHz))
            guard highBin > lowBin else { continue }
            let sum = magnitudes[lowBin..<highBin].reduce(0, +)
            bands[band] = sum / Double(highBin - lowBin)
        }

        // Normalize against the loudest band — silence stays all zeros.
        if let loudest = bands.max(), loudest > 0 {
            bands = bands.map { $0 / loudest }
        }
        return bands
    }
}

/// The daemon's live state file content (`Paths.stateURL`): the
/// equalizer bands plus a timestamp, updated a few times a second.
public struct LiveState: Codable, Equatable {
    public var bands: [Double]
    public var updatedAt: Date

    public init(bands: [Double], updatedAt: Date) {
        self.bands = bands
        self.updatedAt = updatedAt
    }
}
