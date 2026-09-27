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
    /// Verbatim empty title — a literal "" would become a localization key.
    private let emptyTitle = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("device.title").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("action.refresh") { refresh() }
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
        .task { await reloadDevices() }
        .onChange(of: store.speakerMAC) { _, newValue in
            manualInput = newValue ?? ""
            showingInvalidHint = false
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
        devices = await BlueutilDeviceSource.pairedDevices()
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
}
