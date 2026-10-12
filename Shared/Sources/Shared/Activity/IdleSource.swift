import Foundation

/// Source of "seconds since the last user input".
/// A boundary protocol: the daemon depends on it, not on a concrete API —
/// tests substitute a fake.
public protocol IdleSource: Sendable {
    func idleSeconds() -> TimeInterval
}
