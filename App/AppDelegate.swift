import AppKit

/// AppKit lifecycle hooks. The SwiftUI `App` protocol has no
/// `applicationDidFinishLaunching`, so the delegate rides alongside via
/// `@NSApplicationDelegateAdaptor` in `AudioNapApp` and receives the
/// classic lifecycle callbacks.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // The earliest reliable moment to enforce single instance: the
        // process is up and the menu bar item is about to appear.
        SingleInstanceGuard.enforce()
    }
}
