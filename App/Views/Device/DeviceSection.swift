import Shared
import SwiftUI

/// The speaker row in the popup: the device name (falling back to the
/// MAC) and the connect/disconnect toggle. The picker and the list
/// refresh live in the settings window; the popup only displays and
/// toggles. All state and logic live in DeviceSectionViewModel — this
/// view only visualizes them.
struct DeviceSection: View {
    @Bindable var vm: DeviceSectionViewModel

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            PopupSectionHeader("device.title")
            HStack {
                // One line, tail-truncated: a long device name ends
                // with an ellipsis instead of wrapping the section.
                Text(verbatim: vm.deviceName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Button {
                    vm.performToggle()
                } label: {
                    HStack(spacing: 6) {
                        if vm.status?.isTransitioning == true {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text(buttonTitle)
                    }
                    .foregroundStyle(buttonColor)
                }
                .disabled(vm.speakerMAC == nil || vm.status?.isTransitioning == true)
            }
        }
        .task {
            await vm.start()
        }
        .alert("error.title", isPresented: $vm.showingError) {
            Button("action.ok") {}
        } message: {
            Text(vm.errorMessage)
        }
    }

    /// The button shows the action it performs, not the current
    /// state: Disconnect while connected (and while disconnecting),
    /// Connect otherwise — the transitions keep their target label
    /// with a spinner.
    private var buttonTitle: LocalizedStringKey {
        switch vm.status {
        case .connected, .disconnecting: "action.disconnect"
        case nil, .disconnected, .connecting: "action.connect"
        }
    }

    /// Semantic color: the stable states carry the hue (Disconnect
    /// reads destructive, Connect positive), transitions are neutral
    /// like the daemon button's.
    private var buttonColor: Color {
        switch vm.status {
        case .connected: theme.deviceConnected
        case nil, .disconnected: theme.deviceDisconnected
        case .connecting, .disconnecting: theme.statusTransitioning
        }
    }
}
