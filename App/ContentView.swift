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
        .alert("Daemon control error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    /// Colored dot + state text + manual refresh.
    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(controller.isRunning ? theme.statusActive : theme.statusInactive)
                .frame(width: 8, height: 8)
            Text(controller.isRunning ? "Daemon running" : "Daemon stopped")
            Spacer()
            Button("Refresh") { controller.refreshStatus() }
        }
    }

    /// Start/Stop. Each button is disabled in the state where it would be
    /// pointless: starting a running daemon, stopping a stopped one.
    private var controlsRow: some View {
        HStack {
            Button("Start") { perform { try controller.start() } }
                .disabled(controller.isRunning)
            Button("Stop") { perform { try controller.stop() } }
                .disabled(!controller.isRunning)
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
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }

    /// Runs a throwing control action; failures surface in the alert.
    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
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
