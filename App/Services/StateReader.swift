import Foundation
import Observation
import Shared

/// Reads the daemon's live state (equalizer bands) from state.plist on
/// a short timer — the UI's window into the capture signal. Bands
/// reset to zeros when the file is missing or stale, so a stopped
/// daemon reads as a dead equalizer rather than a frozen picture.
@MainActor
@Observable
public final class StateReader {
    /// Stale after this long without an update (the daemon publishes
    /// at 4 Hz; 1.5 s is several missed beats).
    private static let staleAfter: TimeInterval = 1.5

    public private(set) var bands: [Double] = Array(
        repeating: 0, count: AudioBands.bandCount)

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
        let fresh: [Double]?
        if let data = try? Data(contentsOf: Paths.stateURL),
           let state = try? PropertyListDecoder().decode(LiveState.self, from: data),
           state.bands.count == AudioBands.bandCount,
           Date().timeIntervalSince(state.updatedAt) < Self.staleAfter {
            fresh = state.bands
        } else {
            fresh = nil
        }
        bands = fresh ?? Array(repeating: 0, count: AudioBands.bandCount)
    }
}
