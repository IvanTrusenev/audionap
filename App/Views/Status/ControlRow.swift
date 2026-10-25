import SwiftUI

/// Daemon status and the one control in a single row: dot + state text
/// on the left, the start/stop toggle on the right. The toggle stays
/// pinned right — state text changes do not move it. The start/stop
/// operation and its error alert live in ControlRowViewModel; this
/// view keeps the display mappings — semantic colors and localized
/// strings are presentation.
struct ControlRow: View {
    /// The status dot's diameter.
    private static let statusDotSize: CGFloat = 8

    /// The heartbeat truth from StateReader — the settled status comes
    /// from the daemon's own publication, not from launchctl readings.
    let daemonAlive: Bool

    @State private var vm: ControlRowViewModel

    @Environment(\.appTheme) private var theme

    init(controller: DaemonController, daemonAlive: Bool) {
        self.daemonAlive = daemonAlive
        _vm = State(initialValue: ControlRowViewModel(controller: controller))
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stateColor)
                .frame(width: Self.statusDotSize, height: Self.statusDotSize)
            Text(statusText)
            Spacer()
            toggleButton
        }
        .alert("error.title", isPresented: $vm.showingError) {
            Button("action.ok") {}
        } message: {
            Text(vm.errorMessage)
        }
    }

    /// The status the row shows, straight from the model.
    private var displayedStatus: DaemonStatus {
        vm.displayedStatus(daemonAlive: daemonAlive)
    }

    /// Semantic color per daemon state: active, inactive, or the
    /// dimmed directional hue while an operation is in flight.
    private var stateColor: Color {
        switch displayedStatus {
        case .running: theme.statusActive
        case .stopped: theme.statusInactive
        case .starting: theme.statusStarting
        case .stopping: theme.statusStopping
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
            vm.toggle(daemonAlive: daemonAlive)
        } label: {
            HStack(spacing: 6) {
                if vm.isTransitioning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: displayedStatus == .running ? "stop.fill" : "play.fill")
                }
                Text(buttonTitle)
            }
            .foregroundStyle(actionColor)
        }
        .disabled(vm.isTransitioning)
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
