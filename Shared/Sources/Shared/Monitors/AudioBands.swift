import Accelerate
import Foundation

/// Frequency bands of the system audio mix for the equalizer view.
/// Pure math: a Hann-windowed 2048-sample mono frame goes through a
/// radix-2 FFT, bin magnitudes group into 10 log-spaced bands, and the
/// bands normalize against their maximum so the UI reads 0…1.
public enum AudioBands {
    /// 16 log-spaced bands: the most the 23.4 Hz FFT bins support —
    /// every band spans at least one full bin, so no bar reads a
    /// neighbour's frequency (31 bands needed bin sharing at the
    /// bottom). Still well within the visualizer canon (8–20).
    public static let bandCount = 16
    /// Floats per frame: the DSPSplitComplex variant of vDSP.FFT treats
    /// log2n as the log2 of the REAL sample count and produces N/2
    /// packed bins, so 4096 samples (log2n = 12) give ~23.4 Hz bins at
    /// 48 kHz.
    public static let frameSize = 4096

    /// Band edges in Hz: 17 edges delimit 16 log-spaced bands from
    /// 60 Hz to 20 kHz.
    public static let bandEdges: [Double] = {
        let low = 60.0
        let high = 20_000.0
        return (0...bandCount).map { index in
            low * pow(high / low, Double(index) / Double(bandCount))
        }
    }()

    /// Precomputed twiddle factors; shared across calls from a single
    /// capture queue — `nonisolated(unsafe)` is the same pattern as
    /// DaemonLoop.stop for state touched from one well-known context.
    private static nonisolated(unsafe) let fft: vDSP.FFT<DSPSplitComplex> = vDSP.FFT(
        log2n: vDSP_Length(12), radix: .radix2, ofType: DSPSplitComplex.self)!

    /// Computes the normalized band levels of one mono frame. Returns
    /// zeros for a frame of the wrong size or quieter than the playing
    /// threshold — normalization would otherwise inflate a noise floor
    /// (fade-outs, dither, between-track tails) to full height.
    public static func compute(frame: [Float], sampleRate: Double) -> [Double] {
        guard frame.count == frameSize, sampleRate > 0 else {
            return Array(repeating: 0, count: bandCount)
        }

        // The RMS gate: the same threshold the playing decision uses.
        var sum = 0.0
        for sample in frame { sum += Double(sample * sample) }
        let rms = (sum / Double(frameSize)).squareRoot()
        guard rms > ActivityWindow.defaultThreshold else {
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
        // A bin belongs to a band when the bin's CENTER falls inside
        // the band, hence ceil on both edges. The bottom bands are
        // narrower than one bin (23.4 Hz at 48 kHz), so each band gets
        // at least one bin — neighbours may share a bin down there,
        // but no bar stays dead.
        let binHz = sampleRate / Double(frameSize / 2)
        var bands = [Double](repeating: 0, count: bandCount)
        for band in 0..<bandCount {
            let lowBin = max(0, Int((bandEdges[band] / binHz).rounded(.up)))
            let edgeBin = min(frameSize / 2, Int((bandEdges[band + 1] / binHz).rounded(.up)))
            let highBin = max(lowBin + 1, edgeBin)
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
