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

    /// The app's default theme, injected once at the root. The asset
    /// symbols are compile-time checked — a renamed Color Set breaks the
    /// build, not just the look.
    public static let standard = AppTheme(
        statusActive: Color(.statusActive),
        statusInactive: Color(.statusInactive)
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
