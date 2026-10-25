import Foundation
import Observation
import Shared

/// The settings window's presentation model — the SwiftUI counterpart
/// of a feature's bloc/cubit, living next to the view. It bridges the
/// config's Int minutes to the sliders' Double, proxies the bindable
/// config fields (so the view never builds bindings by hand), owns
/// the launch-at-login apply-and-rollback flow and the device list.
/// The view only visualizes it.
@MainActor
@Observable
public final class SettingsWindowViewModel {
    /// The config store — single source of truth, persisted on every
    /// write and hot-reloaded by the daemon.
    private let store: ConfigStore
    /// The launch-at-login service: the agent file's presence is the
    /// truth.
    private let autostart: AutostartController

    /// The paired-device list for the picker; refreshed on appear and
    /// by the refresh button.
    public var devices: [BlueutilDevice] = []

    /// Autostart state comes from the filesystem, not memory: the
    /// toggle survives app restarts and stays honest if the file was
    /// touched. Writing applies the change; a failure rolls the
    /// toggle back to the filesystem's truth.
    public var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            Task { await applyAutostart() }
        }
    }
    /// Text of the last autostart failure, shown in an alert.
    public var autostartErrorMessage = ""
    /// Whether the autostart error alert is visible.
    public var showingAutostartError = false

    public init(store: ConfigStore, autostart: AutostartController) {
        self.store = store
        self.autostart = autostart
        self.launchAtLogin = AutostartController.isEnabled()
    }

    /// The picker selection, proxied straight into the config.
    public var speakerMAC: BluetoothMAC? {
        get { store.speakerMAC }
        set { store.speakerMAC = newValue }
    }

    /// Slider bridges: Slider binds Double, the config stores whole
    /// minutes as Int — the conversion lives here, the view never
    /// sees it.
    public var silenceTimeoutSlider: Double {
        get { Double(store.silenceTimeoutMinutes) }
        set { store.silenceTimeoutMinutes = Int(newValue) }
    }

    public var inputWindowSlider: Double {
        get { Double(store.inputWindowMinutes) }
        set { store.inputWindowMinutes = Int(newValue) }
    }

    /// Whole-minutes values, read-only: the view needs them for the
    /// slider rows' labels (the Double bridges above are for the
    /// sliders themselves). Strings stay in the view.
    public var silenceTimeoutMinutes: Int { store.silenceTimeoutMinutes }

    public var inputWindowMinutes: Int { store.inputWindowMinutes }

    /// Behavior toggles, proxied straight into the config.
    public var ignoreUserActivity: Bool {
        get { store.ignoreUserActivity }
        set { store.ignoreUserActivity = newValue }
    }

    public var speakerOnBattery: Bool {
        get { store.speakerOnBattery }
        set { store.speakerOnBattery = newValue }
    }

    /// Connected devices first — the speaker being set up is usually
    /// connected — then by name.
    public var sortedDevices: [BlueutilDevice] {
        devices.sorted {
            ($0.connected ? 0 : 1, $0.name) < ($1.connected ? 0 : 1, $1.name)
        }
    }

    public func reloadDevices() async {
        devices = await BlueutilRunner.pairedDevices()
    }

    /// Resets timeouts and toggles but never the device: the device
    /// is a choice, not a setting.
    public func restoreDefaults() {
        store.resetDefaults()
        launchAtLogin = false
    }

    /// Applies the autostart toggle to the filesystem; on failure the
    /// toggle snaps back to the filesystem's truth and the error
    /// surfaces in the alert.
    private func applyAutostart() async {
        do {
            try await autostart.setEnabled(launchAtLogin)
        } catch {
            launchAtLogin = AutostartController.isEnabled()
            autostartErrorMessage = error.localizedDescription
            showingAutostartError = true
        }
    }
}
