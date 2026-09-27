import AppKit
import SwiftUI

/// The menu bar window: daemon status and Start/Stop controls.
///
/// MVP scope (M3): a status row, controls, and a Quit button —
/// device picker, settings, and the log tail arrive in M4.
struct ContentView: View {
    /// Owns the view model for the app's lifetime. `@State` creates it once
    /// and keeps it across redraws; `DaemonController` is `@Observable`, so
    /// SwiftUI re-renders this view when a property it read in `body` changes.
    @State private var controller = DaemonController()

    /// Text of the last Start/Stop failure, shown in an alert.
    @State private var errorMessage = ""
    /// Whether the alert is visible.
    @State private var showingError = false
    /// Config: reads config.plist once, saves every slider change.
    @State private var store = ConfigStore()
    /// Tail of daemon.log, refreshed on appear and by the Refresh button.
    @State private var logReader = LogReader()
    
    /// Design tokens, injected at the app root; defaults to `.standard`.
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusRow
            Divider()
            controlsRow
            Divider()
            settingsSection
            Divider()
            logSection
            Divider()
            quitRow
        }
        .padding()
        .frame(width: 340)
        .onAppear {
            controller.refreshStatus()
            logReader.refresh()
        }
        .alert("error.title", isPresented: $showingError) {
            Button("action.ok") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    /// Colored dot + state text + manual refresh.
    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
            Text(statusText)
            Spacer()
            Button("action.refresh") { controller.refreshStatus() }
        }
    }

    /// Semantic color per daemon state: active, inactive, or neutral
    /// while an operation is in flight.
    private var stateColor: Color {
        switch controller.status {
        case .running: theme.statusActive
        case .stopped: theme.statusInactive
        case .starting, .stopping: theme.statusTransitioning
        }
    }

    /// The button shows the action it performs, not the current state:
    /// starting is a positive action (active), stopping a negative one
    /// (inactive), transitions are neutral.
    private var actionColor: Color {
        switch controller.status {
        case .running: theme.statusInactive
        case .stopped: theme.statusActive
        case .starting, .stopping: theme.statusTransitioning
        }
    }
    
    /// Status text per state. `LocalizedStringKey`, not `String` — a
    /// plain String variable would hit `Text(verbatim:)` and skip
    /// localization.
    private var statusText: LocalizedStringKey {
        switch controller.status {
        case .running: "status.daemon.running"
        case .stopped: "status.daemon.stopped"
        case .starting: "status.daemon.starting"
        case .stopping: "status.daemon.stopping"
        }
    }
    
    /// One toggle button: starts or stops depending on the daemon state.
    /// During a transition the button is disabled and shows a spinner —
    /// launchd settles jobs asynchronously, so the state is not instant.
    private var controlsRow: some View {
        Button {
            perform {
                if controller.status == .running {
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
                    Image(systemName: controller.status == .running ? "stop.fill" : "play.fill")
                }
                Text(buttonTitle)
            }
            .foregroundStyle(actionColor)
        }
        .disabled(controller.status.isTransitioning)
    }

    private var buttonTitle: LocalizedStringKey {
        switch controller.status {
        case .running: "action.stop"
        case .stopped: "action.start"
        case .starting: "status.daemon.starting"
        case .stopping: "status.daemon.stopping"
        }
    }

    /// Timeout sliders — changes persist to config.plist on every tick.
    private var settingsSection: some View {
        SettingsControls(store: store)
    }

    /// The daemon log tail — see what the daemon is doing without a terminal.
    private var logSection: some View {
        LogSection(reader: logReader)
    }

    /// A window-style MenuBarExtra has no application menu, so the window
    /// needs its own Quit button.
    private var quitRow: some View {
        HStack {
            Spacer()
            Button("action.quit") { NSApplication.shared.terminate(nil) }
        }
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

#Preview("Light") {
    ContentView()
        .appTheme(.standard)
}

#Preview("Dark") {
    ContentView()
        .appTheme(.standard)
        .preferredColorScheme(.dark)
}
