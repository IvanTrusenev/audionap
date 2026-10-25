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
                        if vm.isUpdatingConnection {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text(vm.isConnected == true ? "action.disconnect" : "action.connect")
                    }
                    .foregroundStyle(vm.isConnected == true ? theme.statusInactive : theme.statusActive)
                }
                .disabled(vm.speakerMAC == nil || vm.isUpdatingConnection)
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
}
