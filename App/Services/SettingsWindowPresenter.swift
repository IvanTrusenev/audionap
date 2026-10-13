import AppKit

/// Brings the already-open settings window to the front. SwiftUI's
/// openWindow creates a window but never re-fronts an existing one, so
/// a settings window buried under another app would swallow clicks and
/// the button would look dead. The window is captured when it appears;
/// later clicks activate the app and front it.
@MainActor
public final class SettingsWindowPresenter {
    private weak var window: NSWindow?

    public init() {}

    public func capture(_ window: NSWindow) {
        self.window = window
    }

    /// Called on every settings-button click, after openWindow — the
    /// first click only opens (no window captured yet), later clicks
    /// front the existing one.
    public func front() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
