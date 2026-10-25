import SwiftUI

/// A settings row with a switch pinned right. A plain Toggle would sit
/// the control right after the label text, so the label owns the
/// stretch instead — the Spacer inside it takes the free width and
/// the switch lands on the trailing edge. The 44 pt row matches the
/// System Settings row pitch (measured), so every item gets the same
/// height wherever it stands; `controlSize(.mini)` keeps the compact
/// switch of the original design.
public struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    public init(_ title: LocalizedStringKey, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            HStack {
                Text(title)
                Spacer()
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .frame(height: 44)
    }
}
