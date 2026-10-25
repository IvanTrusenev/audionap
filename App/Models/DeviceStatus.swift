import Foundation

/// The speaker connection from the app's point of view. blueutil
/// reconnects take time and the speaker can be off, so between a
/// toggle and the confirmed state there is a transition phase
/// (`connecting`/`disconnecting`) — the UI disables the button there
/// instead of trusting a stale reading. Transition states are
/// directions, so no illegal value (like a nested transition) exists.
public enum DeviceStatus: Equatable {
    case disconnected
    case connected
    /// An operation is in flight — the speaker is being connected.
    case connecting
    /// An operation is in flight — the speaker is being disconnected.
    case disconnecting

    /// Events the app can produce; the only two transitions it makes.
    public enum Event: Equatable {
        case operationStarted
        case operationSettled(connected: Bool)
    }

    /// The next state after an event — the whole state machine.
    public static func next(
        from current: DeviceStatus, event: Event
    ) -> DeviceStatus {
        switch event {
        case .operationStarted:
            switch current {
            case .disconnected: return .connecting
            case .connected: return .disconnecting
            case .connecting: return .connecting
            case .disconnecting: return .disconnecting
            }
        case .operationSettled(let connected):
            return connected ? .connected : .disconnected
        }
    }

    /// True only while an operation is in flight.
    public var isTransitioning: Bool {
        switch self {
        case .connecting, .disconnecting: return true
        case .connected, .disconnected: return false
        }
    }
}
