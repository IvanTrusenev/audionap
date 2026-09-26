import CoreGraphics
import Foundation
import Shared

/// Implementation via the public CoreGraphics API: seconds since the last
/// HID event (keyboard/mouse), no Accessibility permissions needed.
public struct IdleMonitor: IdleSource {
    public init() {}

    /// `kCGAnyInputEventType` ("any input event") is not imported into Swift
    /// as a case, so it's built from its documented raw value (UInt32.max —
    /// always valid, hence the force unwrap).
    private static let anyInputEventType = CGEventType(rawValue: .max)!

    public func idleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: Self.anyInputEventType
        )
    }
}
