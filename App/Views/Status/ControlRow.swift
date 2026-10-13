import SwiftUI

/// Daemon status and the one control in a single row: dot + state text
/// on the left, the start/stop toggle on the right. The toggle stays
/// pinned right — state text changes do not move it.
/// Owns its own error alert: only this row produces daemon control errors.
struct ControlRow: View {
    let controller: DaemonController
    /// The heartbeat truth from StateReader — the settled status comes
    /// from the daemon's own publication, not from launchctl readings.
    let daemonAlive: Bool

    /// Text of the last Start/Stop failure, shown in an alert.
    @State private var errorMessage = ""
    /// Whether the alert is visible.
    @State private var showingError = false

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
            Text(statusText)
            Spacer()
            toggleButton
        }
        .alert("error.title", isPresented: $showingError) {
            Button("action.ok") {}
        } message: {
            Text(errorMessage)
        }
    }

    /// The status the row shows: a local transition while an operation
    /// is in flight, otherwise the heartbeat truth — an externally
    /// stopped daemon reads as stopped within the heartbeat's
    /// freshness window, without any refresh.
    private var displayedStatus: DaemonStatus {
        controller.status.isTransitioning
            ? controller.status
            : (daemonAlive ? .running : .stopped)
    }

    /// Semantic color per daemon state: active, inactive, or neutral
    /// while an operation is in flight.
    private var stateColor: Color {
        switch displayedStatus {
        case .running: theme.statusActive
        case .stopped: theme.statusInactive
        case .starting, .stopping: theme.statusTransitioning
        }
    }

    /// Status text per state. `LocalizedStringKey`, not `String` — a
    /// plain String variable would hit `Text(verbatim:)` and skip
    /// localization.
    private var statusText: LocalizedStringKey {
        switch displayedStatus {
        case .running: "status.daemon.running"
        case .stopped: "status.daemon.stopped"
        case .starting: "status.daemon.starting"
        case .stopping: "status.daemon.stopping"
        }
    }

    /// The button shows the action it performs, not the current state:
    /// starting is a positive action (active), stopping a negative one
    /// (inactive), transitions are neutral.
    private var actionColor: Color {
        switch displayedStatus {
        case .running: theme.statusInactive
        case .stopped: theme.statusActive
        case .starting, .stopping: theme.statusTransitioning
        }
    }

    private var buttonTitle: LocalizedStringKey {
        switch displayedStatus {
        case .running: "action.stop"
        case .stopped: "action.start"
        case .starting: "status.daemon.starting"
        case .stopping: "status.daemon.stopping"
        }
    }

    /// The start/stop toggle: shows the action it performs (symbol,
    /// label, color); disabled with a spinner during transitions.
    private var toggleButton: some View {
        Button {
            perform {
                // The local machine may lag the heartbeat (an external
                // stop), so sync it first — the transition must start
                // from the truth.
                controller.adopt(alive: daemonAlive)
                if displayedStatus == .running {
                    try await controller.stop()
                } else {
                    try await controller.start()
                }
            }
        } label: {
            HStack(spacing: 6) {
                if controller.status.isTransitioning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: displayedStatus == .running ? "stop.fill" : "play.fill")
                }
                Text(buttonTitle)
            }
            .foregroundStyle(actionColor)
        }
        .disabled(controller.status.isTransitioning)
    }

    /// Runs a throwing control action asynchronously; failures surface in
    /// the alert. The task inherits the main actor, so the UI stays
    /// responsive while the blocking launchctl work runs off the actor.
    private func perform(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

#Preview("Stopped") {
    ControlRow(controller: DaemonController(status: .stopped), daemonAlive: false)
        .appTheme(.standard)
        .padding()
}

#Preview("Running") {
    ControlRow(controller: DaemonController(status: .running), daemonAlive: true)
        .appTheme(.standard)
        .padding()
}

#Preview("Transition") {
    ControlRow(controller: DaemonController(status: .starting), daemonAlive: false)
        .appTheme(.standard)
        .padding()
}
