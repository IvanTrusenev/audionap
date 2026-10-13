import AppKit
import SwiftUI

/// The menu bar window: assembles the app's widgets — the daemon status
/// and control row, the signal slot, the device row, and Quit. The
/// widgets own their internals; this view only arranges them.
struct ContentView: View {
    /// The config store is shared with the settings window — injected
    /// from the app, not owned here.
    let store: ConfigStore
    /// Shared with the settings window for the launch-at-login toggle.
    let autostart: AutostartController

    /// Owns the view model for the app's lifetime. `@State` creates it once
    /// and keeps it across redraws; `DaemonController` is `@Observable`, so
    /// SwiftUI re-renders this view when a property it read in `body` changes.
    @State private var controller = DaemonController()

    /// Tail of daemon.log, refreshed on appear and by the Refresh button.
    @State private var logReader = LogReader()

    /// Provisions the bundled daemon on first window open.
    @State private var installer = DaemonInstaller()

    /// The daemon's live state (equalizer bands), refreshed on a timer
    /// while the window is open.
    @State private var stateReader = StateReader()

    /// Install failures surface in an alert (same pattern as ControlRow).
    @State private var installErrorMessage = ""

    @State private var showingInstallError = false

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ControlRow(controller: controller, daemonAlive: stateReader.daemonAlive)
            // The signal slot exists only while the daemon is alive —
            // a stopped daemon hides it and the dividers collapse into
            // one instead of stacking two in a row.
            if stateReader.daemonAlive {
                SignalSection(
                    bands: stateReader.bands,
                    playing: stateReader.playing,
                    quietSeconds: stateReader.quietSeconds,
                    idleSeconds: stateReader.idleSeconds,
                    // The thresholds are config, not runtime state: the
                    // store is their fresher truth than the daemon's
                    // publication round-trip.
                    silenceTimeoutSeconds: store.silenceTimeoutSeconds,
                    inputWindowSeconds: store.inputWindowSeconds,
                    ignoreIdle: store.ignoreUserActivity)
            }
            Divider()
            DeviceSection(store: store)
            Divider()
            #if DEBUG
            LogSection(reader: logReader)
            Divider()
            #endif
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
    /// needs its own Quit button. The settings gear is a temporary
    /// trigger for the new window — the final bottom row arrives with
    /// the next stage.
    private var quitRow: some View {
        HStack {
            Spacer()
            Button {
                openWindow(id: "settings")
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            Button("action.quit") { NSApplication.shared.terminate(nil) }
        }
    }
}

#Preview("Light") {
    ContentView(store: ConfigStore(), autostart: AutostartController())
        .appTheme(.standard)
}

#Preview("Dark") {
    ContentView(store: ConfigStore(), autostart: AutostartController())
        .appTheme(.standard)
        .preferredColorScheme(.dark)
}
