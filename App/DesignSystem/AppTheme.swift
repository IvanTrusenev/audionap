import SwiftUI

/// Semantic design tokens of the app UI. Views never pick raw hues — they
/// read a meaning (`statusActive`) from the theme, and the theme resolves it
/// to a Color Set from the asset catalog, which carries the Light/Dark
/// variants. A future palette change edits the catalog and this struct,
/// never the views.
public struct AppTheme: Sendable {
    /// The status dot while the daemon is running.
    public var statusActive: Color
    /// The status dot while the daemon is stopped.
    public var statusInactive: Color
    /// The neutral color of the daemon controls while an operation
    /// is in flight.
    public var statusTransitioning: Color
    /// The equalizer's cold end — the green the bars start from.
    /// A dedicated token, not `statusActive`: "daemon alive" and "low
    /// audio level" are different meanings that happen to share a hue
    /// today; either palette may change independently later.
    public var equalizerCold: Color
    /// The equalizer's middle stop — the VU-meter amber.
    public var equalizerAmber: Color
    /// The equalizer's hot end — the red the bars grow toward.
    public var equalizerHot: Color

    /// The equalizer's fixed background: the strip's full height is
    /// painted in the broadcast VU-meter scale — green (bottom), amber
    /// (middle), red (top) — and each bar's height is a mask revealing
    /// the bottom of it. The gradient must never be stretched to a
    /// bar's own bounds.
    public var equalizerBar: LinearGradient {
        LinearGradient(
            colors: [equalizerCold, equalizerAmber, equalizerHot],
            startPoint: .bottom,
            endPoint: .top)
    }

    /// The app's default theme, injected once at the root. The asset
    /// symbols are compile-time checked — a renamed Color Set breaks the
    /// build, not just the look.
    public static let standard = AppTheme(
        statusActive: Color(.statusActive),
        statusInactive: Color(.statusInactive),
        statusTransitioning: Color(.statusTransitioning),
        equalizerCold: Color(.equalizerCold),
        equalizerAmber: Color(.equalizerAmber),
        equalizerHot: Color(.equalizerHot)
    )
}

// MARK: - Environment

/// The injection key. Views read it as `@Environment(\.appTheme)`; the
/// default keeps them working even where no theme was injected (previews,
/// tests).
private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .standard
}

public extension EnvironmentValues {
    /// The active `AppTheme`, `.standard` unless overridden.
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

public extension View {
    /// Injects a theme for this view and its subtree — the SwiftUI
    /// counterpart of Flutter's `Theme(data:)`. Called once at the root;
    /// any subtree may override it with another theme.
    func appTheme(_ theme: AppTheme) -> some View {
        environment(\.appTheme, theme)
    }
}
