import Foundation
import Observation

/// The control row's presentation model: owns the daemon controller
/// reference and the start/stop operation with its error alert. The
/// view keeps the display mappings — colors and localized strings are
/// presentation.
@MainActor
@Observable
public final class ControlRowViewModel {
    private let controller: DaemonController

    /// Text of the last Start/Stop failure, shown in an alert.
    public var errorMessage = ""
    /// Whether the alert is visible.
    public var showingError = false

    public init(controller: DaemonController) {
        self.controller = controller
    }

    /// Whether an operation is in flight — the spinner and the
    /// disabled state read this.
    public var isTransitioning: Bool { controller.status.isTransitioning }

    /// The status the row shows: a local transition while an operation
    /// is in flight, otherwise the heartbeat truth — an externally
    /// stopped daemon reads as stopped within the heartbeat's
    /// freshness window, without any refresh.
    public func displayedStatus(daemonAlive: Bool) -> DaemonStatus {
        controller.status.isTransitioning
            ? controller.status
            : (daemonAlive ? .running : .stopped)
    }

    /// Start/stop per the displayed status; failures surface in the
    /// alert. The local machine may lag the heartbeat (an external
    /// stop), so sync it first — the transition must start from the
    /// truth. The decision is made right after the adopt, before the
    /// async work starts.
    public func toggle(daemonAlive: Bool) {
        controller.adopt(alive: daemonAlive)
        let running = displayedStatus(daemonAlive: daemonAlive) == .running
        Task {
            do {
                if running {
                    try await controller.stop()
                } else {
                    try await controller.start()
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}
