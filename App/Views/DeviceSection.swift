import Shared
import SwiftUI

/// The device picker: the speaker AudioNap babysits. The list comes from
/// `blueutil --paired` (connected devices first); the manual field is
/// always available — the fallback when blueutil or the device list is
/// unavailable.
struct DeviceSection: View {
    let store: ConfigStore

    @State private var devices: [BlueutilDevice] = []
    /// Manual MAC entry — a draft, committed to the store on submit.
    @State private var manualInput = ""
    /// True when the last submit was not a MAC address.
    @State private var showingInvalidHint = false
    /// Text of the last reconnect failure, shown in an alert.
    @State private var errorMessage = ""
    /// Whether the error alert is visible.
    @State private var showingError = false
    /// Last known connection state; refreshed on open, after each
    /// action, and by a poll while the window is open.
    @State private var isConnected = false
    /// True while a connect/disconnect operation is in flight.
    @State private var isUpdatingConnection = false
    /// Verbatim empty title — a literal "" would become a localization key.
    private let emptyTitle = ""

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("device.title").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("action.refresh") { refresh() }
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
                        Text(isConnected ? "action.disconnect" : "action.connect")
                    }
                    .foregroundStyle(isConnected ? theme.statusInactive : theme.statusActive)
                }
                .disabled(store.speakerMAC == nil || isUpdatingConnection)
            }
            Picker("device.title", selection: selectedMAC) {
                Text("device.none").tag(String?.none)
                ForEach(sortedDevices, id: \.address) { device in
                    Text(verbatim: "\(device.name) — \(device.address)")
                        .tag(String?.some(device.address))
                }
            }
            .labelsHidden()
            if sortedDevices.isEmpty {
                Text("device.empty").font(.caption).foregroundStyle(.secondary)
            }
            TextField(emptyTitle, text: $manualInput, prompt: Text(verbatim: "aa-bb-cc-dd-ee-ff"))
                .onSubmit(submitManual)
            if showingInvalidHint {
                Text("device.invalidMAC").font(.caption).foregroundStyle(.secondary)
            }
        }
        .task {
            await reloadDevices()
            await refreshConnectionState()
            await pollConnectionState()
        }
        .onChange(of: store.speakerMAC) { _, newValue in
            manualInput = newValue ?? ""
            showingInvalidHint = false
        }
        .alert("error.title", isPresented: $showingError) {
            Button("action.ok") {}
        } message: {
            Text(errorMessage)
        }
    }

    /// Picker selection writes straight into the config store — the
    /// daemon hot-reloads, the manual field mirrors it.
    private var selectedMAC: Binding<String?> {
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

    private func refresh() {
        Task { await reloadDevices() }
    }

    private func reloadDevices() async {
        devices = await BlueutilRunner.pairedDevices()
    }

    /// Commits the manual entry when it normalizes to a MAC; otherwise
    /// shows the hint and keeps the stored value untouched.
    private func submitManual() {
        guard let normalized = BluetoothMAC.normalize(manualInput) else {
            showingInvalidHint = true
            return
        }
        store.speakerMAC = normalized
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
                if isConnected {
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
