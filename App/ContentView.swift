import AppKit
import SwiftUI

/// The menu bar window: assembles the app's widgets — the daemon status
/// and control row, settings, the log tail, and Quit. The widgets own
/// their internals; this view only arranges them.
struct ContentView: View {
    /// Owns the view model for the app's lifetime. `@State` creates it once
    /// and keeps it across redraws; `DaemonController` is `@Observable`, so
    /// SwiftUI re-renders this view when a property it read in `body` changes.
    @State private var controller = DaemonController()
    /// Config: reads config.plist once, saves every slider change.
    @State private var store = ConfigStore()
    /// Tail of daemon.log, refreshed on appear and by the Refresh button.
    @State private var logReader = LogReader()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ControlRow(controller: controller)
            Divider()
            settingsSection
            #if DEBUG
            Divider()
            logSection
            #endif
            Divider()
            quitRow
        }
        .padding()
        .frame(width: 340)
        .onAppear {
            controller.refreshStatus()
            logReader.refresh()
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
