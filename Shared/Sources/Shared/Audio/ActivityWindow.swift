import Foundation

/// A rolling window of audio activity: `slotCount` time slots of
/// `slotDuration` seconds each. Every audio buffer marks the slot it
/// falls into as active when its RMS exceeds the threshold; readers ask
/// what fraction of the last window was active. This is the honest
/// "is sound playing" metric: a short burst (one slot) contributes
/// little, sustained audio fills the window.
///
/// Pure logic, no audio APIs — unit-testable without hardware.
public struct ActivityWindow {
    /// Activity threshold: silence measures 0.00000 RMS, quiet music
    /// ~0.001+, normal playback 0.04–0.37 (measured on the dev speaker).
    public static let defaultThreshold = 0.005
    /// Fraction of active time required to count as playing — a 1s
    /// notification burst (10% of the window) stays below it.
    public static let defaultPlayingFraction = 0.3

    public let slotDuration: TimeInterval
    /// Slots older than this are ignored by the fraction.
    public var windowDuration: TimeInterval { slotDuration * Double(slots.count) }

    /// The default window (10 s) — also the stall threshold for the
    /// capture: buffers arriving more rarely than this read as a frozen
    /// stream.
    public static let defaultWindowDuration: TimeInterval = 10

    /// (timestamp, active) per slot. Timestamp 0 = slot never written.
    private var slots: [(at: TimeInterval, active: Bool)]

    public init(slotCount: Int = 100, slotDuration: TimeInterval = 0.1) {
        self.slotDuration = slotDuration
        self.slots = Array(repeating: (at: 0, active: false), count: slotCount)
    }

    /// Marks the slot containing `now` active or inactive.
    public mutating func mark(active: Bool, at now: TimeInterval) {
        let index = Int(now / slotDuration) % slots.count
        slots[index] = (at: now, active: active)
    }

    /// The fraction of non-stale slots that are active, or nil when no
    /// slot has been written yet.
    public func activeFraction(at now: TimeInterval) -> Double? {
        let fresh = slots.filter { $0.at > 0 && now - $0.at <= windowDuration }
        guard !fresh.isEmpty else { return nil }
        return Double(fresh.filter(\.active).count) / Double(fresh.count)
    }

    /// Whether the window reads as playing at `now`.
    public func isPlaying(at now: TimeInterval) -> Bool {
        (activeFraction(at: now) ?? 0) >= Self.defaultPlayingFraction
    }
}
