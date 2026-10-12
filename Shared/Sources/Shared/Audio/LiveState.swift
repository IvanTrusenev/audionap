import Foundation

/// The daemon's live state file content (`Paths.stateURL`): the
/// equalizer bands plus the playback/activity facts the UI draws,
/// updated at 10 Hz.
public struct LiveState: Codable, Equatable {
    public var bands: [Double]
    /// Whether audio is reaching the speaker right now — the same
    /// gate && window rule the decision consumes.
    public var playing: Bool
    /// Consecutive seconds of silence counted by the loop.
    public var quietSeconds: Int
    /// Seconds since the last user input.
    public var idleSeconds: Int
    /// The silence threshold of the active config, in seconds.
    public var silenceTimeoutSeconds: Int
    /// The user-input threshold of the active config, in seconds.
    public var inputWindowSeconds: Int
    public var updatedAt: Date

    public init(
        bands: [Double],
        playing: Bool,
        quietSeconds: Int,
        idleSeconds: Int,
        silenceTimeoutSeconds: Int,
        inputWindowSeconds: Int,
        updatedAt: Date
    ) {
        self.bands = bands
        self.playing = playing
        self.quietSeconds = quietSeconds
        self.idleSeconds = idleSeconds
        self.silenceTimeoutSeconds = silenceTimeoutSeconds
        self.inputWindowSeconds = inputWindowSeconds
        self.updatedAt = updatedAt
    }
}
