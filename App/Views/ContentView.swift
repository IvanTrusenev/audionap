import AppKit
import SwiftUI

/// The menu bar window: assembles the app's widgets — the daemon status
/// and control row, the signal slot, the device row, and the bottom
/// row. The view models own the internals; this view only arranges
/// the widgets.
struct ContentView: View {
    /// The popup's fixed width — a menu bar window does not resize.
    private static let popupWidth: CGFloat = 340

    /// Fronts the app's windows on repeated clicks.
    let windowPresenter: WindowPresenter

    /// The window's presentation model — owns the daemon controller,
    /// the live-state reader and the installer.
    @State private var vm: ContentViewModel
    /// The device section's presentation model — owns the device
    /// list, the connection poll and the connect/disconnect
    /// operation. The slot gate reads its `isConnected`.
    @State private var deviceVM: DeviceSectionViewModel

    @Environment(\.openWindow) private var openWindow

    init(store: ConfigStore, windowPresenter: WindowPresenter) {
        self.windowPresenter = windowPresenter
        _vm = State(initialValue: ContentViewModel(store: store))
        _deviceVM = State(initialValue: DeviceSectionViewModel(store: store))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ControlRow(controller: vm.controller, daemonAlive: vm.daemonAlive)
            // The signal slot exists only while it can mean something:
            // the daemon alive and the speaker connected. A stopped
            // daemon or a disconnected speaker hides it and its
            // divider, so the dividers collapse into one instead of
            // stacking.
            if vm.daemonAlive && deviceVM.showsSignalSlot {
                Divider()
                SignalSection(
                    bands: vm.bands,
                    playing: vm.playing,
                    quietSeconds: vm.quietSeconds,
                    idleSeconds: vm.idleSeconds,
                    silenceTimeoutSeconds: vm.silenceTimeoutSeconds,
                    inputWindowSeconds: vm.inputWindowSeconds,
                    ignoreIdle: vm.ignoreUserActivity)
            }
            Divider()
            DeviceSection(vm: deviceVM)
            Divider()
            bottomRow
        }
        .padding()
        .frame(width: Self.popupWidth)
        // The slot's appear/disappear animates the window's height
        // too — a menu bar window follows its content.
        .animation(.easeOut(duration: 0.2), value: vm.daemonAlive)
        .animation(.easeOut(duration: 0.2), value: deviceVM.showsSignalSlot)
        // A menu bar window ignores preferredColorScheme — register
        // it with the store, which sets the appearance on open and on
        // every theme change.
        .background(WindowCapture(onWindow: { window in
            AppearanceStore.shared.register(window)
        }))
        .onAppear {
            vm.start()
        }
        .onDisappear {
            vm.stop()
        }
        .task {
            await vm.ensureDaemonInstalled()
        }
        .alert("error.daemonInstall.title", isPresented: $vm.showingInstallError) {
            Button("action.ok") {}
        } message: {
            Text(vm.installErrorMessage)
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
        windowPresenter: WindowPresenter())
        .appTheme(.standard)
}

#Preview("Dark") {
    ContentView(
        store: ConfigStore(),
        windowPresenter: WindowPresenter())
        .appTheme(.standard)
        .preferredColorScheme(.dark)
}
