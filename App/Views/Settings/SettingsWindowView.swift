import Shared
import SwiftUI

/// The settings window: device, timeouts, behavior — everything that
/// left the popup for the roomier window. All changes persist through
/// the shared ConfigStore and hot-reload the daemon. Restore Defaults
/// resets timeouts and toggles but never the device: the device is a
/// choice, not a setting.
///
/// A custom layout, not a native Form: the design's controls are
/// full-width with the label above (sliders) or pinned right
/// (toggles), and a grouped Form's column machinery squeezes them
/// into the control column.
struct SettingsWindowView: View {
    let store: ConfigStore
    let autostart: AutostartController
    /// Fronts this window on repeated settings-button clicks.
    let presenter: WindowPresenter

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
        VStack(alignment: .leading, spacing: 0) {
            SettingsSection("device.title") {
                // The mockup's one-line row: the picker and the
                // refresh icon. The section header names the domain;
                // the picker's hidden label still serves accessibility.
                HStack {
                    Picker("settings.speaker", selection: selectedMAC) {
                        Text("device.none").tag(BluetoothMAC?.none)
                        ForEach(sortedDevices, id: \.address) { device in
                            Text(verbatim: "\(device.name) — \(device.address)")
                                .tag(BluetoothMAC?.some(device.address))
                        }
                        // The picker must always offer the current
                        // selection among its tags — SwiftUI logs
                        // "invalid selection" otherwise. The paired
                        // list loads async, so on the first frames the
                        // configured device is not among the rows yet;
                        // the bare address stands in for its row until
                        // the list arrives (or forever, if the device
                        // is no longer paired).
                        if let mac = store.speakerMAC,
                           !sortedDevices.contains(where: { $0.address == mac }) {
                            Text(verbatim: mac.value)
                                .tag(BluetoothMAC?.some(mac))
                        }
                    }
                    .labelsHidden()
                    Spacer()
                    Button {
                        Task { await reloadDevices() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("action.refresh")
                }
                if sortedDevices.isEmpty {
                    Text("device.empty")
                        .font(AppTypography.helper)
                        .foregroundStyle(.secondary)
                }
            }
            groupSpacing
            SettingsSection("settings.timeouts") {
                VStack(spacing: 0) {
                    SettingsSliderRow(
                        label: timeoutLabel(
                            String(localized: "settings.silenceTimeout"),
                            minutes: store.silenceTimeoutMinutes
                        ),
                        value: Binding(
                            get: { Double(store.silenceTimeoutMinutes) },
                            set: { store.silenceTimeoutMinutes = Int($0) }
                        ),
                        range: AppConfig.silenceTimeoutRange
                    )
                    .padding(.bottom, 10)
                    Divider()
                    SettingsSliderRow(
                        label: timeoutLabel(
                            String(localized: "settings.idleWindow"),
                            minutes: store.inputWindowMinutes
                        ),
                        value: Binding(
                            get: { Double(store.inputWindowMinutes) },
                            set: { store.inputWindowMinutes = Int($0) }
                        ),
                        range: AppConfig.inputWindowRange
                    )
                    .padding(.top, 10)
                }
            }
            groupSpacing
            SettingsSection("settings.behavior", flush: true) {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        "settings.ignoreUserActivity",
                        isOn: Binding(
                            get: { store.ignoreUserActivity },
                            set: { store.ignoreUserActivity = $0 }
                        )
                    )
                    Divider()
                    SettingsToggleRow(
                        "settings.speakerOnBattery",
                        isOn: Binding(
                            get: { store.speakerOnBattery },
                            set: { store.speakerOnBattery = $0 }
                        )
                    )
                    Divider()
                    SettingsToggleRow(
                        "settings.launchAtLogin",
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
            }
            groupSpacing
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
        .padding(12)
        .frame(width: 380)
        // Every button in this window is a small accessory icon —
        // the shared hover style is injected once, not per button.
        .buttonStyle(HoverButtonStyle())
        .background(WindowCapture(onWindow: { presenter.capture($0, as: .settings) }))
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

    /// The gap between groups: empty space, no divider line — the
    /// native settings separate their cards with air, not rules.
    /// 31 pt from the card's bottom edge to the next group's header,
    /// measured against System Settings.
    private var groupSpacing: some View {
        Spacer().frame(height: 31)
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

    /// The slider row's label: one localized template with two
    /// placeholders (title and minute count), so the word order can
    /// differ per language.
    private func timeoutLabel(_ title: String, minutes: Int) -> String {
        String(localized: "settings.timeoutValue \(title) \(minutes)")
    }
}

#Preview {
    SettingsWindowView(
        store: ConfigStore(),
        autostart: AutostartController(),
        presenter: WindowPresenter())
        .appTheme(.standard)
}
