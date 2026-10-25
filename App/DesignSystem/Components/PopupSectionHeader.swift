import SwiftUI

/// The compact title above a popup section: the section-header role of
/// the menu bar window, styled here once so no view spells out its
/// font. Dimmer than the settings window's header — the popup's
/// hierarchy is flatter.
public struct PopupSectionHeader: View {
    let title: LocalizedStringKey

    public init(_ title: LocalizedStringKey) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(AppTypography.popupSectionHeader)
            .foregroundStyle(.secondary)
    }
}
