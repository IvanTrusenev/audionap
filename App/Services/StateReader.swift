import Foundation
import Observation
import Shared

/// Reads the daemon's live state from state.plist on a short timer —
/// the UI's window into the capture signal and the daemon's heartbeat.
/// The file is the shared medium between two processes: freshness is
/// aliveness. Bands and facts reset to zeros when the file is missing
/// or stale, so a stopped daemon reads as a dead picture rather than
/// a frozen one.
@MainActor
@Observable
public final class StateReader {
    /// Stale after this long without an update — the daemon publishes
    /// at 10 Hz, so 1.5 s is many missed beats.
    private static let staleAfter: TimeInterval = 1.5

    public private(set) var bands: [Double] = Array(
        repeating: 0, count: AudioBands.bandCount)
    /// Whether the daemon is alive: the state file was written
    /// recently enough.
    public private(set) var daemonAlive = false
    /// Whether audio is reaching the speaker, per the daemon.
    public private(set) var playing = false
    /// Consecutive silence seconds, per the daemon.
    public private(set) var quietSeconds = 0
    /// Seconds since the last user input, per the daemon.
    public private(set) var idleSeconds = 0
    /// The active silence threshold in seconds.
    public private(set) var silenceTimeoutSeconds = 0
    /// The active user-input threshold in seconds.
    public private(set) var inputWindowSeconds = 0

    private var timer: Timer?

    public init() {}

    /// Starts the refresh timer (fires on the main run loop, matching
    /// the daemon's 10 Hz publication).
    public func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        refresh()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        let state: LiveState?
        if let data = try? Data(contentsOf: Paths.stateURL),
           let decoded = try? PropertyListDecoder().decode(LiveState.self, from: data),
           decoded.bands.count == AudioBands.bandCount,
           Date().timeIntervalSince(decoded.updatedAt) < Self.staleAfter {
            state = decoded
        } else {
            state = nil
        }
        daemonAlive = state != nil
        bands = state?.bands ?? Array(repeating: 0, count: AudioBands.bandCount)
        playing = state?.playing ?? false
        quietSeconds = state?.quietSeconds ?? 0
        idleSeconds = state?.idleSeconds ?? 0
        silenceTimeoutSeconds = state?.silenceTimeoutSeconds ?? 0
        inputWindowSeconds = state?.inputWindowSeconds ?? 0
    }
}
