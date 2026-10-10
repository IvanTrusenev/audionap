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

    /// Provisions the bundled daemon on first window open.
    @State private var installer = DaemonInstaller()

    /// Manages the LaunchAgents copy that enables launch-at-login.
    @State private var autostart = AutostartController()

    /// The daemon's live state (equalizer bands), refreshed on a timer
    /// while the window is open.
    @State private var stateReader = StateReader()

    /// Install failures surface in an alert (same pattern as ControlRow).
    @State private var installErrorMessage = ""

    @State private var showingInstallError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ControlRow(controller: controller)
            EqualizerView(bands: stateReader.bands)
            Divider()
            DeviceSection(store: store)
            Divider()
            SettingsControls(store: store, autostart: autostart)
            #if DEBUG
            Divider()
            LogSection(reader: logReader)
            #endif
            Divider()
            quitRow
        }
        .padding()
        .frame(width: 340)
        .onAppear {
            controller.refreshStatus()
            logReader.refresh()
            stateReader.start()
        }
        .onDisappear {
            stateReader.stop()
        }
        .task {
            // Preview hosts run the whole app (same bundle ID) and unit
            // tests host it too — neither should install the daemon.
            let environment = ProcessInfo.processInfo.environment
            guard environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1",
                  environment["XCTestConfigurationFilePath"] == nil else {
                return
            }
            do {
                _ = try await installer.ensureInstalled()
            } catch {
                installErrorMessage = error.localizedDescription
                showingInstallError = true
            }
        }
        .alert("error.daemonInstall.title", isPresented: $showingInstallError) {
            Button("action.ok") {}
        } message: {
            Text(installErrorMessage)
        }
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
