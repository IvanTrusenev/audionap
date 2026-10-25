import Shared
import SwiftUI

/// The speaker row in the popup: the device name (falling back to the
/// MAC) and the connect/disconnect toggle. The picker and the list
/// refresh live in the settings window; the popup only displays and
/// toggles.
struct DeviceSection: View {
    let store: ConfigStore

    /// The paired list, only to resolve the selected MAC into a name.
    @State private var devices: [BlueutilDevice] = []
    /// The speaker's connection state, owned by the parent (the signal
    /// slot hides while the speaker is disconnected): `nil` until the
    /// first poll answers, so the UI can tell "unknown" from
    /// "confirmed disconnected" and avoid flicker.
    @Binding var isConnected: Bool?
    /// True while a connect/disconnect operation is in flight.
    @State private var isUpdatingConnection = false
    /// Text of the last reconnect failure, shown in an alert.
    @State private var errorMessage = ""
    /// Whether the error alert is visible.
    @State private var showingError = false

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            PopupSectionHeader("device.title")
            HStack {
                // One line, tail-truncated: a long device name ends
                // with an ellipsis instead of wrapping the section.
                Text(verbatim: deviceName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Button {
                    performToggle()
                } label: {
                    HStack(spacing: 6) {
                        if isUpdatingConnection {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text(isConnected == true ? "action.disconnect" : "action.connect")
                    }
                    .foregroundStyle(isConnected == true ? theme.statusInactive : theme.statusActive)
                }
                .disabled(store.speakerMAC == nil || isUpdatingConnection)
            }
        }
        .task {
            await reloadDevices()
            await refreshConnectionState()
            await pollConnectionState()
        }
        .alert("error.title", isPresented: $showingError) {
            Button("action.ok") {}
        } message: {
            Text(errorMessage)
        }
    }

    /// The selected device's name, falling back to the MAC — the
    /// design's read-only display.
    private var deviceName: String {
        guard let mac = store.speakerMAC else {
            return String(localized: "device.none")
        }
        return devices.first(where: { $0.address == mac })?.name ?? mac.description
    }

    private func reloadDevices() async {
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

    /// Polls the connection state every 2 s while the window is open —
    /// the task is cancelled when the view disappears. Skips polling
    /// while an operation is in flight.
    private func pollConnectionState() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            guard !isUpdatingConnection else { continue }
            await refreshConnectionState()
        }
    }

    /// Connects or disconnects depending on the last known state;
    /// re-reads the state after the operation, failures surface in the
    /// alert.
    private func performToggle() {
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
