import Foundation
import Observation
import Shared

/// The device section's presentation model: resolves the selected MAC
/// into a name, polls the connection state, and runs the
/// connect/disconnect operation. The popup reads `isConnected` from
/// here to hide the signal slot while the speaker is disconnected.
@MainActor
@Observable
public final class DeviceSectionViewModel {
    /// How often the connection state is re-read from blueutil.
    private static let pollInterval: Duration = .seconds(2)

    private let store: ConfigStore

    /// The paired list, only to resolve the selected MAC into a name.
    public var devices: [BlueutilDevice] = []
    /// Last known connection state: `nil` until the first poll
    /// answers, so the UI can tell "unknown" from "confirmed
    /// disconnected" and avoid flicker.
    public var isConnected: Bool? = nil
    /// True while a connect/disconnect operation is in flight.
    public var isUpdatingConnection = false
    /// Text of the last failure, shown in an alert.
    public var errorMessage = ""
    /// Whether the error alert is visible.
    public var showingError = false

    public init(store: ConfigStore) {
        self.store = store
    }

    /// The selected device, read-only for the disabled state.
    public var speakerMAC: BluetoothMAC? { store.speakerMAC }

    /// The selected device's name, falling back to the MAC — the
    /// design's read-only display.
    public var deviceName: String {
        guard let mac = store.speakerMAC else {
            return LanguageStore.shared.string("device.none")
        }
        return devices.first(where: { $0.address == mac })?.name ?? mac.description
    }

    /// Runs while the window is open: loads the list, reads the
    /// connection, then polls it every 2 s. The task is cancelled when
    /// the view disappears.
    public func start() async {
        await reloadDevices()
        await refreshConnectionState()
        await pollConnectionState()
    }

    public func reloadDevices() async {
        devices = await BlueutilRunner.pairedDevices()
    }

    /// Re-reads the connection state from blueutil; no-op without a
    /// selected device.
    private func refreshConnectionState() async {
        guard let mac = store.speakerMAC else {
            isConnected = false
            return
        }
        isConnected = await BlueutilRunner.isConnected(to: mac)
    }

    /// Polls the connection state; skips polling while an operation is
    /// in flight.
    private func pollConnectionState() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.pollInterval)
            guard !isUpdatingConnection else { continue }
            await refreshConnectionState()
        }
    }

    /// Connects or disconnects depending on the last known state;
    /// re-reads the state after the operation, failures surface in
    /// the alert.
    public func performToggle() {
        guard let mac = store.speakerMAC else { return }
        isUpdatingConnection = true
        Task {
            do {
                if isConnected == true {
                    try await BlueutilRunner.disconnect(from: mac)
                } else {
                    try await BlueutilRunner.connect(to: mac)
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            await refreshConnectionState()
            isUpdatingConnection = false
        }
    }
}
