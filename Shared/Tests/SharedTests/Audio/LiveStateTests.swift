import Foundation
import Testing

@testable import Shared

struct LiveStateTests {

    /// The full snapshot must survive a binary-plist round trip — the
    /// app reads exactly what the daemon writes, field by field.
    @Test func liveStateRoundtripsThroughThePlist() throws {
        let state = LiveState(
            bands: [0.1, 0.5, 1.0],
            playing: true,
            quietSeconds: 120,
            idleSeconds: 45,
            silenceTimeoutSeconds: 900,
            inputWindowSeconds: 180,
            updatedAt: Date())
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(state)
        let decoded = try PropertyListDecoder().decode(LiveState.self, from: data)
        #expect(decoded.bands == state.bands)
        #expect(decoded.playing == state.playing)
        #expect(decoded.quietSeconds == state.quietSeconds)
        #expect(decoded.idleSeconds == state.idleSeconds)
        #expect(decoded.silenceTimeoutSeconds == state.silenceTimeoutSeconds)
        #expect(decoded.inputWindowSeconds == state.inputWindowSeconds)
        #expect(abs(decoded.updatedAt.timeIntervalSince(state.updatedAt)) < 1)
    }
}
