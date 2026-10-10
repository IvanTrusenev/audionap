import Foundation
import Testing

@testable import Shared

struct AudioBandsTests {

    /// A 440 Hz sine at full scale: its energy must land in the
    /// 250–500 Hz band (band index 2) and nowhere else.
    @Test func sine440LandsInItsBand() {
        let sampleRate = 48_000.0
        var frame = [Float](repeating: 0, count: AudioBands.frameSize)
        for i in 0..<AudioBands.frameSize {
            frame[i] = Float(sin(2 * .pi * 440 * Double(i) / sampleRate))
        }
        let bands = AudioBands.compute(frame: frame, sampleRate: sampleRate)

        #expect(bands.count == AudioBands.bandCount)
        #expect(bands[2] > 0.9)
        // Normalized: the loudest band is 1.0.
        #expect(abs(bands.max()! - 1.0) < 0.001)
        // Neighbouring bands are far quieter; the upper neighbour may
        // catch the Hann main lobe's tail on the boundary bin, hence
        // the looser bound there.
        #expect(bands[1] < 0.1)
        #expect(bands[3] < 0.3)
    }

    @Test func silenceYieldsZeroBands() {
        let frame = [Float](repeating: 0, count: AudioBands.frameSize)
        let bands = AudioBands.compute(frame: frame, sampleRate: 48_000)
        #expect(bands.allSatisfy { $0 == 0 })
    }

    @Test func wrongFrameSizeYieldsZeros() {
        let bands = AudioBands.compute(frame: [0, 1, 2], sampleRate: 48_000)
        #expect(bands.allSatisfy { $0 == 0 })
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
