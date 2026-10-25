import SwiftUI

/// Semantic typography tokens of the app UI, the text counterpart of
/// `AppTheme`. Views reference roles (`sectionHeader`), never raw sizes
/// and weights, so a style change edits this file, not the views.
///
/// The tokens carry fonts only: color is the orthogonal
/// `foregroundStyle` axis and defaults to primary. A view overrides
/// the color on the spot when a role needs another one — no
/// font-plus-color pairs live here, that combination would not scale.
public enum AppTypography {
    /// The title above a settings card.
    public static let sectionHeader: Font = .body.weight(.semibold)
    /// The compact title above a popup section.
    public static let popupSectionHeader: Font = .caption
    /// The small line under a control that needs explaining.
    public static let helper: Font = .caption
    /// The log window's monospaced lines.
    public static let log: Font = .system(size: 11, design: .monospaced)
    /// The Jump-to-Now button's arrow symbol.
    public static let jumpButtonIcon: Font = .system(size: 12, weight: .semibold)
}
