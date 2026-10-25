import SwiftUI

/// A settings card: the SectionHeader role over the group's content,
/// wrapped in the inset container of the modern System Settings look.
/// `flush` cards hold a list of rows edge-to-edge (no vertical
/// padding, like a native list card), padded cards hold controls.
public struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    /// Whether the card holds edge-to-edge rows.
    var flush: Bool
    @ViewBuilder var content: () -> Content

    public init(
        _ title: LocalizedStringKey,
        flush: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.flush = flush
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title)
            content()
                .padding(.horizontal, 10)
                .padding(.vertical, flush ? 0 : 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                )
        }
    }

    /// The card's title: the section-header role, styled here once so
    /// no view spells out its font. Color stays the default primary.
    /// Nested until a second consumer needs the header on its own.
    private struct SectionHeader: View {
        let title: LocalizedStringKey

        var body: some View {
            Text(title).font(AppTypography.sectionHeader)
        }
    }
}
