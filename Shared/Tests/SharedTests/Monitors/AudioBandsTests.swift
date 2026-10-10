import Foundation
import Testing

@testable import Shared

struct AudioBandsTests {

    /// A 440 Hz sine at full scale: its energy must land in the band
    /// covering 440 Hz (band 5 of the 16 log-spaced bands) and
    /// nowhere else.
    @Test func sine440LandsInItsBand() {
        let sampleRate = 48_000.0
        var frame = [Float](repeating: 0, count: AudioBands.frameSize)
        for i in 0..<AudioBands.frameSize {
            frame[i] = Float(sin(2 * .pi * 440 * Double(i) / sampleRate))
        }
        let bands = AudioBands.compute(frame: frame, sampleRate: sampleRate)

        #expect(bands.count == AudioBands.bandCount)
        #expect(bands[5] > 0.9)
        // Normalized: the loudest band is 1.0.
        #expect(abs(bands.max()! - 1.0) < 0.001)
        // Neighbouring bands are far quieter; the Hann main lobe
        // spills into the direct neighbours, hence the bounds.
        #expect(bands[4] < 0.4)
        #expect(bands[6] < 0.4)
    }

    @Test func silenceYieldsZeroBands() {
        let frame = [Float](repeating: 0, count: AudioBands.frameSize)
        let bands = AudioBands.compute(frame: frame, sampleRate: 48_000)
        #expect(bands.allSatisfy { $0 == 0 })
    }

    /// A barely-audible frame (RMS well below the playing threshold)
    /// must also read as silence: normalization against the loudest
    /// band would otherwise inflate the noise floor to full height —
    /// the "twitching between tracks" artifact.
    @Test func noiseFloorYieldsZeroBands() {
        let sampleRate = 48_000.0
        var frame = [Float](repeating: 0, count: AudioBands.frameSize)
        for i in 0..<AudioBands.frameSize {
            frame[i] = Float(sin(2 * .pi * 440 * Double(i) / sampleRate)) * 0.001
        }
        let bands = AudioBands.compute(frame: frame, sampleRate: sampleRate)
        #expect(bands.allSatisfy { $0 == 0 })
    }

    @Test func wrongFrameSizeYieldsZeros() {
        let bands = AudioBands.compute(frame: [0, 1, 2], sampleRate: 48_000)
        #expect(bands.allSatisfy { $0 == 0 })
    }

    /// White noise spreads energy evenly: every band must read
    /// nonzero — a dead band would mean its bin mapping is off.
    @Test func whiteNoiseLightsEveryBand() {
        var generator = SystemRandomNumberGenerator()
        var frame = [Float](repeating: 0, count: AudioBands.frameSize)
        for i in 0..<AudioBands.frameSize {
            frame[i] = Float.random(in: -1...1, using: &generator)
        }
        let bands = AudioBands.compute(frame: frame, sampleRate: 48_000)
        #expect(bands.allSatisfy { $0 > 0 })
    }

    @Test func liveStateRoundtripsThroughThePlist() throws {
        let state = LiveState(bands: [0.1, 0.5, 1.0], updatedAt: Date())
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(state)
        let decoded = try PropertyListDecoder().decode(LiveState.self, from: data)
        #expect(decoded.bands == state.bands)
        #expect(abs(decoded.updatedAt.timeIntervalSince(state.updatedAt)) < 1)
    }
}
