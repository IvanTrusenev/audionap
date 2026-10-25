import Foundation
import Observation
import Shared

/// The device section's presentation model: resolves the selected MAC
/// into a name, runs the connect/disconnect state machine, and polls
/// the connection state. The popup reads `showsSignalSlot` from here
/// to hide the signal slot while the speaker is disconnected.
@MainActor
@Observable
public final class DeviceSectionViewModel {
    /// How often the connection state is re-read from blueutil.
    private static let pollInterval: Duration = .seconds(2)
    /// How long a connect/disconnect may take before the settle
    /// accepts the last reading — blueutil's call returning is not
    /// the connection.
    private static let settleDeadline: TimeInterval = 7

    private let store: ConfigStore

    /// The paired list, only to resolve the selected MAC into a name.
    public var devices: [BlueutilDevice] = []
    /// The connection state machine. `nil` until the first poll
    /// answers, so the UI can tell "unknown" from "confirmed
    /// disconnected" and avoid flicker on open.
    public var status: DeviceStatus? = nil
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

    /// The signal slot's visibility: the speaker connected (or the
    /// state not read yet — hiding before the first poll would flash
    /// the slot on every popup open).
    public var showsSignalSlot: Bool {
        switch status {
        case nil, .connected, .connecting: true
        case .disconnected, .disconnecting: false
        }
    }

    /// Runs while the window is open: loads the list, reads the
    /// connection, then polls it. The task is cancelled when the view
    /// disappears.
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
            status = .disconnected
            return
        }
        let connected = await BlueutilRunner.isConnected(to: mac)
        status = DeviceStatus.next(
            from: status ?? .disconnected,
            event: .operationSettled(connected: connected))
    }

    /// Polls the connection state; skips polling while an operation
    /// is in flight, so a stale reading never overwrites a transition.
    private func pollConnectionState() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.pollInterval)
            guard status?.isTransitioning != true else { continue }
            await refreshConnectionState()
        }
    }

    /// Connects or disconnects depending on the state; the button
    /// stays disabled with a spinner until blueutil confirms the
    /// target state, failures surface in the alert.
    public func performToggle() {
        guard let mac = store.speakerMAC else { return }
        guard status?.isTransitioning != true else { return }
        let current = status ?? .disconnected
        status = DeviceStatus.next(from: current, event: .operationStarted)
        Task {
            do {
                if status == .disconnecting {
                    try await BlueutilRunner.disconnect(from: mac)
                } else {
                    try await BlueutilRunner.connect(to: mac)
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            await settleConnection(to: mac)
        }
    }

    /// Settles on a confirmed reading: polls `--is-connected` until
    /// the target state is confirmed or the deadline passes — the
    /// daemon-stop settle's counterpart for the speaker.
    private func settleConnection(to mac: BluetoothMAC) async {
        let target = status == .disconnecting ? false : true
        let deadlineDate = Date().addingTimeInterval(Self.settleDeadline)
        while Date() < deadlineDate {
            let connected = await BlueutilRunner.isConnected(to: mac)
            if connected == target {
                status = DeviceStatus.next(
                    from: status!, event: .operationSettled(connected: connected))
                return
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        // Deadline passed: settle on the last reading — honest, not
        // stuck in a transition forever.
        let connected = await BlueutilRunner.isConnected(to: mac)
        status = DeviceStatus.next(
            from: status!, event: .operationSettled(connected: connected))
    }
}
