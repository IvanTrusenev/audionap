import AppKit
import SwiftUI

/// The menu bar window: assembles the app's widgets — the daemon status
/// and control row, the signal slot, the device row, and the bottom
/// row. The widgets own their internals; this view only arranges them.
struct ContentView: View {
    /// The config store is shared with the settings window — injected
    /// from the app, not owned here.
    let store: ConfigStore
    /// Shared with the settings window for the launch-at-login toggle.
    let autostart: AutostartController
    /// Fronts the app's windows on repeated clicks.
    let windowPresenter: WindowPresenter

    /// Owns the view model for the app's lifetime. `@State` creates it once
    /// and keeps it across redraws; `DaemonController` is `@Observable`, so
    /// SwiftUI re-renders this view when a property it read in `body` changes.
    @State private var controller = DaemonController()

    /// Provisions the bundled daemon on first window open.
    @State private var installer = DaemonInstaller()

    /// The daemon's live state (equalizer bands), refreshed on a timer
    /// while the window is open.
    @State private var stateReader = StateReader()

    /// Install failures surface in an alert (same pattern as ControlRow).
    @State private var installErrorMessage = ""

    @State private var showingInstallError = false

    /// The speaker's connection state, polled by DeviceSection and
    /// hoisted here: the signal slot is pointless while the speaker is
    /// disconnected, so it hides with it. `nil` until the first poll —
    /// "unknown" keeps the slot visible to avoid a flicker on open.
    @State private var speakerConnected: Bool? = nil

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ControlRow(controller: controller, daemonAlive: stateReader.daemonAlive)
            // The signal slot exists only while it can mean something:
            // the daemon alive and the speaker connected. A stopped
            // daemon or a disconnected speaker hides it and its
            // divider, so the dividers collapse into one instead of
            // stacking.
            if stateReader.daemonAlive && speakerConnected != false {
                Divider()
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
            DeviceSection(store: store, isConnected: $speakerConnected)
            Divider()
            bottomRow
        }
        .padding()
        .frame(width: 340)
        .onAppear {
            controller.refreshStatus()
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

    /// The bottom row: settings on the left, Logs (DEBUG) and Quit on
    /// the right, all in the shared HoverButtonStyle, injected once on
    /// the row. A window-style MenuBarExtra has no application menu, so
    /// the window needs its own Quit button; the gear fronts the
    /// settings window on repeated clicks.
    private var bottomRow: some View {
        HStack {
            Button {
                openWindow(id: "settings")
                windowPresenter.front(.settings)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                    Text("action.settings")
                }
            }
            Spacer()
            // The right pair gets its own gap: without it "Logs" and
            // the power icon read as one text-icon-text blob.
            HStack(spacing: 24) {
                #if DEBUG
                Button {
                    openWindow(id: "logs")
                    windowPresenter.front(.logs)
                } label: {
                    Text("action.logs")
                }
                #endif
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                        Text("action.quit")
                    }
                }
            }
        }
        .buttonStyle(HoverButtonStyle())
    }
}

#Preview("Light") {
    ContentView(
        store: ConfigStore(),
        autostart: AutostartController(),
        windowPresenter: WindowPresenter())
        .appTheme(.standard)
}

#Preview("Dark") {
    ContentView(
        store: ConfigStore(),
        autostart: AutostartController(),
        windowPresenter: WindowPresenter())
        .appTheme(.standard)
        .preferredColorScheme(.dark)
}
