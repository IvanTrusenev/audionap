import Foundation

/// The daemon's state from the app's point of view. launchd tears jobs
/// down asynchronously, so between a control call and the settled state
/// there is a transition phase (`starting`/`stopping`) — the UI disables
/// controls there instead of trusting a stale reading. Transition states
/// are directions, so no illegal value (like a nested transition) exists.
public enum DaemonStatus: Equatable {
    case stopped
    case running
    /// An operation is in flight — the daemon is being started.
    case starting
    /// An operation is in flight — the daemon is being stopped.
    case stopping

    /// Events the app can produce; the only two transitions it makes.
    public enum Event: Equatable {
        case operationStarted
        case operationSettled(running: Bool)
    }

    /// The next state after an event — the whole state machine.
    public static func next(from current: DaemonStatus, event: Event) -> DaemonStatus {
        switch event {
        case .operationStarted:
            switch current {
            case .stopped: return .starting
            case .running: return .stopping
            case .starting: return .starting
            case .stopping: return .stopping
            }
        case .operationSettled(let running):
            return running ? .running : .stopped
        }
    }

    /// True only while an operation is in flight.
    public var isTransitioning: Bool {
        switch self {
        case .starting, .stopping: return true
        case .stopped, .running: return false
        }
    }
}
