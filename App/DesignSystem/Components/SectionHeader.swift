import SwiftUI

/// The title above a settings card: the section-header role, styled
/// here once so no view spells out its font. Color stays the default
/// primary; override with `foregroundStyle` where a role needs
/// another one.
public struct SectionHeader: View {
    let title: LocalizedStringKey

    public init(_ title: LocalizedStringKey) {
        self.title = title
    }

    public var body: some View {
        Text(title).font(AppTypography.sectionHeader)
    }
}
