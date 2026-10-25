import Shared
import SwiftUI

/// The settings window: device, timeouts, behavior — everything that
/// left the popup for the roomier window. The view only visualizes
/// the SettingsWindowViewModel: all bindings point into it, all
/// changes persist through the shared ConfigStore and hot-reload the
/// daemon.
///
/// A custom layout, not a native Form: the design's controls are
/// full-width with the label above (sliders) or pinned right
/// (toggles), and a grouped Form's column machinery squeezes them
/// into the control column.
struct SettingsWindowView: View {
    /// Fronts this window on repeated settings-button clicks.
    let presenter: WindowPresenter
    /// The presentation model — created once for the window's
    /// lifetime, like the popup's StateReader.
    @State private var vm: SettingsWindowViewModel

    init(store: ConfigStore, autostart: AutostartController, presenter: WindowPresenter) {
        self.presenter = presenter
        _vm = State(initialValue: SettingsWindowViewModel(store: store, autostart: autostart))
    }

    var body: some View {
        @Bindable var vm = vm
        VStack(alignment: .leading, spacing: 0) {
            SettingsSection("device.title") {
                // The mockup's one-line row: the picker and the
                // refresh icon. The section header names the domain;
                // the picker's hidden label still serves accessibility.
                HStack {
                    Picker("settings.speaker", selection: $vm.speakerMAC) {
                        Text("device.none").tag(BluetoothMAC?.none)
                        ForEach(vm.sortedDevices, id: \.address) { device in
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
                        if let mac = vm.speakerMAC,
                           !vm.sortedDevices.contains(where: { $0.address == mac }) {
                            Text(verbatim: mac.value)
                                .tag(BluetoothMAC?.some(mac))
                        }
                    }
                    .labelsHidden()
                    Spacer()
                    Button {
                        Task { await vm.reloadDevices() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("action.refresh")
                }
                if vm.sortedDevices.isEmpty {
                    Text("device.empty")
                        .font(AppTypography.helper)
                        .foregroundStyle(.secondary)
                }
            }
            groupSpacing
            SettingsSection("settings.timeouts") {
                VStack(spacing: 0) {
                    // The label is one localized template with two
                    // placeholders (title and minute count), so the
                    // word order can differ per language.
                    SettingsSliderRow(
                        label: String(localized: "settings.timeoutValue \(String(localized: "settings.silenceTimeout")) \(vm.silenceTimeoutMinutes)"),
                        value: $vm.silenceTimeoutSlider,
                        range: AppConfig.silenceTimeoutRange
                    )
                    .padding(.bottom, 10)
                    Divider()
                    SettingsSliderRow(
                        label: String(localized: "settings.timeoutValue \(String(localized: "settings.idleWindow")) \(vm.inputWindowMinutes)"),
                        value: $vm.inputWindowSlider,
                        range: AppConfig.inputWindowRange
                    )
                    .padding(.top, 10)
                }
            }
            groupSpacing
            SettingsSection("settings.behavior", flush: true) {
                VStack(spacing: 0) {
                    SettingsToggleRow("settings.ignoreUserActivity", isOn: $vm.ignoreUserActivity)
                    Divider()
                    SettingsToggleRow("settings.speakerOnBattery", isOn: $vm.speakerOnBattery)
                    Divider()
                    SettingsToggleRow("settings.launchAtLogin", isOn: $vm.launchAtLogin)
                }
            }
            groupSpacing
            Button("settings.restoreDefaults") {
                vm.restoreDefaults()
            }
        }
        .padding(12)
        .frame(width: 380)
        // Every button in this window is a small accessory icon —
        // the shared hover style is injected once, not per button.
        .buttonStyle(HoverButtonStyle())
        .background(WindowCapture(onWindow: { presenter.capture($0, as: .settings) }))
        .task {
            await vm.reloadDevices()
        }
        .alert("error.autostart.title", isPresented: $vm.showingAutostartError) {
            Button("action.ok") {}
        } message: {
            Text(vm.autostartErrorMessage)
        }
    }

    /// The gap between groups: empty space, no divider line — the
    /// native settings separate their cards with air, not rules.
    /// 31 pt from the card's bottom edge to the next group's header,
    /// measured against System Settings.
    private var groupSpacing: some View {
        Spacer().frame(height: 31)
    }
}

#Preview {
    SettingsWindowView(
        store: ConfigStore(),
        autostart: AutostartController(),
        presenter: WindowPresenter())
        .appTheme(.standard)
}
