import Shared
import SwiftUI

/// The settings window: device, timeouts, behavior — everything that
/// left the popup for the roomier window. All changes persist through
/// the shared ConfigStore and hot-reload the daemon. Restore Defaults
/// resets timeouts and toggles but never the device: the device is a
/// choice, not a setting.
struct SettingsWindowView: View {
    let store: ConfigStore
    let autostart: AutostartController
    /// Fronts this window on repeated settings-button clicks.
    let presenter: SettingsWindowPresenter

    /// The paired-device list for the picker; refreshed on appear and
    /// by the refresh button.
    @State private var devices: [BlueutilDevice] = []
    /// Autostart state comes from the filesystem, not memory: the
    /// toggle survives app restarts and stays honest if the file was
    /// touched.
    @State private var launchAtLogin = false
    @State private var autostartErrorMessage = ""
    @State private var showingAutostartError = false

    var body: some View {
        Form {
            Section("device.title") {
                Picker("device.title", selection: selectedMAC) {
                    Text("device.none").tag(BluetoothMAC?.none)
                    ForEach(sortedDevices, id: \.address) { device in
                        Text(verbatim: "\(device.name) — \(device.address)")
                            .tag(BluetoothMAC?.some(device.address))
                    }
                }
                HStack {
                    if sortedDevices.isEmpty {
                        Text("device.empty")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("action.refresh") {
                        Task { await reloadDevices() }
                    }
                }
            }
            Section("settings.timeouts") {
                slider(
                    title: String(localized: "settings.silenceTimeout"),
                    binding: Binding(
                        get: { Double(store.silenceTimeoutMinutes) },
                        set: { store.silenceTimeoutMinutes = Int($0) }
                    ),
                    range: AppConfig.silenceTimeoutRange
                )
                slider(
                    title: String(localized: "settings.idleWindow"),
                    binding: Binding(
                        get: { Double(store.inputWindowMinutes) },
                        set: { store.inputWindowMinutes = Int($0) }
                    ),
                    range: AppConfig.inputWindowRange
                )
            }
            Section("settings.behavior") {
                toggleRow(
                    title: "settings.ignoreUserActivity",
                    isOn: Binding(
                        get: { store.ignoreUserActivity },
                        set: { store.ignoreUserActivity = $0 }
                    )
                )
                toggleRow(
                    title: "settings.speakerOnBattery",
                    isOn: Binding(
                        get: { store.speakerOnBattery },
                        set: { store.speakerOnBattery = $0 }
                    )
                )
                toggleRow(
                    title: "settings.launchAtLogin",
                    isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            launchAtLogin = newValue
                            Task {
                                do {
                                    try await autostart.setEnabled(newValue)
                                } catch {
                                    // The filesystem is the truth: re-read it
                                    // so the toggle snaps back honestly.
                                    launchAtLogin = AutostartController.isEnabled()
                                    autostartErrorMessage = error.localizedDescription
                                    showingAutostartError = true
                                }
                            }
                        }
                    )
                )
            }
            Section {
                Button("settings.restoreDefaults") {
                    store.resetDefaults()
                    launchAtLogin = false
                    Task {
                        do {
                            try await autostart.setEnabled(false)
                        } catch {
                            launchAtLogin = AutostartController.isEnabled()
                            autostartErrorMessage = error.localizedDescription
                            showingAutostartError = true
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .background(WindowCapture(onWindow: presenter.capture))
        .task {
            await reloadDevices()
        }
        .onAppear {
            launchAtLogin = AutostartController.isEnabled()
        }
        .alert("error.autostart.title", isPresented: $showingAutostartError) {
            Button("action.ok") {}
        } message: {
            Text(autostartErrorMessage)
        }
    }

    /// Picker selection writes straight into the config store — the
    /// daemon hot-reloads.
    private var selectedMAC: Binding<BluetoothMAC?> {
        Binding(
            get: { store.speakerMAC },
            set: { store.speakerMAC = $0 }
        )
    }

    /// Connected devices first — the speaker being set up is usually
    /// connected — then by name.
    private var sortedDevices: [BlueutilDevice] {
        devices.sorted {
            ($0.connected ? 0 : 1, $0.name) < ($1.connected ? 0 : 1, $1.name)
        }
    }

    private func reloadDevices() async {
        devices = await BlueutilRunner.pairedDevices()
    }

    /// A settings row: the switch pinned right. A plain Toggle would sit
    /// the control right after the label text, so the label owns the
    /// stretch instead — the Spacer inside it takes the free width and
    /// the switch lands on the trailing edge. `controlSize(.mini)`
    /// matches the compact switches in System Settings; the macOS pill
    /// renders large by default.
    private func toggleRow(
        title: LocalizedStringKey, isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack {
                Text(title)
                Spacer()
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
    }

    /// Labeled slider. Slider only binds BinaryFloatingPoint values, so the
    /// Int setting travels through an explicit Double bridge; `step: 1`
    /// makes the setter fire on whole minutes only. The range comes from
    /// AppConfig — product limits live in one place.
    /// The label is one localized template with two placeholders (title and
    /// minute count), so the word order can differ per language.
    private func slider(
        title: String, binding: Binding<Double>, range: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("settings.timeoutValue \(title) \(Int(binding.wrappedValue))")
            Slider(
                value: binding,
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
        }
    }
}

#Preview {
    SettingsWindowView(
        store: ConfigStore(),
        autostart: AutostartController(),
        presenter: SettingsWindowPresenter())
        .appTheme(.standard)
}

/// Reports the hosting NSWindow when it appears — the presenter uses
/// it to re-front the settings window on repeated clicks, which
/// openWindow alone cannot do.
struct WindowCapture: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.onWindow = onWindow
    }

    /// A plain NSView sees its window only in didMoveToWindow — the
    /// one reliable moment to capture it.
    final class CaptureView: NSView {
        var onWindow: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window {
                onWindow?(window)
            }
        }
    }
}
