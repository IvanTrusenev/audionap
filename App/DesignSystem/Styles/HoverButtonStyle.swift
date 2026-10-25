import SwiftUI

/// The shared style of icon/text accessory buttons, in the macOS
/// canon: dimmed at rest, a soft rounded fill on hover — the
/// selection highlight of a menu item, no border, no color flip.
/// Injected once on the container (the popup's footer row, the
/// settings window) instead of being repeated per button.
public struct HoverButtonStyle: ButtonStyle {
    @State private var hovering = false

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hovering ? Color.primary.opacity(0.08) : .clear)
            )
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.1), value: hovering)
    }
}
