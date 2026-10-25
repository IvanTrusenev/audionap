import Foundation
import Observation
import SwiftUI

/// The app's appearance mode — system, light or dark. A UI preference,
/// not a daemon setting: it lives in UserDefaults, not config.plist.
/// Applied once per window via the `appAppearance()` modifier.
/// Nonisolated by design — UserDefaults is thread-safe and the
/// service layer reads the language store from Sendable error types.
@Observable
public final class AppearanceStore {
    public enum Mode: String, CaseIterable {
        case system
        case light
        case dark
    }

    /// The one instance — UserDefaults is already global, the store
    /// is its thin typed wrapper.
    public static let shared = AppearanceStore()

    private static let storageKey = "appearanceMode"

    public var mode: Mode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
            applyToWindows()
        }
    }

    /// The windows that registered for the store's theme — weak, the
    /// store must never keep a closed window alive.
    private var windows: [WeakBox] = []

    private init() {
        mode = Mode(rawValue: UserDefaults.standard.string(forKey: Self.storageKey) ?? "") ?? .system
    }

    /// Registers a window and applies the current mode to it right
    /// away; from then on every mode change reaches it directly.
    /// Registration is the window's only duty — no per-view
    /// onChange plumbing.
    public func register(_ window: NSWindow) {
        windows.removeAll { $0.window == nil }
        if !windows.contains(where: { $0.window === window }) {
            windows.append(WeakBox(window))
        }
        window.appearance = nsAppearance
    }

    /// Applies the current appearance to every registered window —
    /// the theme switch reaches all of them at once, open or not.
    private func applyToWindows() {
        for box in windows {
            box.window?.appearance = nsAppearance
        }
    }

    /// A dictionary-free weak box, as in WindowPresenter.
    private final class WeakBox {
        weak var window: NSWindow?
        init(_ window: NSWindow) { self.window = window }
    }

    /// The scheme the windows apply — nil means "follow the system".
    public var colorScheme: ColorScheme? {
        switch mode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// The concrete scheme the content renders in: the chosen mode,
    /// or the system's current scheme when following it. Always
    /// concrete — the environment cannot hold a "follow the system"
    /// value, and branching the modifier off broke the updates.
    public var resolvedColorScheme: ColorScheme {
        switch mode {
        case .light: .light
        case .dark: .dark
        case .system:
            NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? .dark : .light
        }
    }

    /// The NSAppearance the windows apply — nil follows the system.
    /// Windows set it directly: preferredColorScheme lags updating
    /// the content of a WindowGroup window (text stays dark on a
    /// dark background until the window is refronted) and is ignored
    /// by the menu bar window entirely.
    public var nsAppearance: NSAppearance? {
        switch mode {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

public extension View {
    /// Applies the app's appearance and language to a window's root.
    /// preferredColorScheme drives the window's NSAppearance (the
    /// background follows), the always-concrete environment drives
    /// the content — both are always in the tree, only the values
    /// change, so a theme switch updates them together. The menu bar
    /// window ignores preferredColorScheme; it registers with the
    /// store instead (see ContentView).
    func appAppearance() -> some View {
        self
            .preferredColorScheme(AppearanceStore.shared.colorScheme)
            .environment(\.colorScheme, AppearanceStore.shared.resolvedColorScheme)
            .environment(\.locale, LanguageStore.shared.locale)
    }
}
