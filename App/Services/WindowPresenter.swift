import AppKit
import SwiftUI

/// Brings an already-open app window to the front. SwiftUI's openWindow
/// creates a window but never re-fronts an existing one, so a window
/// buried under another app would swallow clicks and its button would
/// look dead. Each window is captured when it appears; later clicks
/// activate the app and front it.
@MainActor
public final class WindowPresenter {
    /// The app's windows, keyed by their scene id.
    public enum WindowID: String {
        case settings
        case logs
    }

    private var windows: [WindowID: WeakBox] = [:]

    public init() {}

    public func capture(_ window: NSWindow, as id: WindowID) {
        windows[id] = WeakBox(window)
    }

    /// Called on every window-button click, after openWindow — the
    /// first click only opens (no window captured yet), later clicks
    /// front the existing one.
    public func front(_ id: WindowID) {
        windows[id]?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// A dictionary cannot hold weak references directly — box them.
    private final class WeakBox {
        weak var window: NSWindow?
        init(_ window: NSWindow) { self.window = window }
    }
}

/// Reports the hosting NSWindow when it appears — the presenter uses
/// it to re-front windows on repeated clicks, which openWindow alone
/// cannot do. A plain NSView sees its window only in didMoveToWindow,
/// the one reliable moment to capture it.
struct WindowCapture: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.onWindow = onWindow
    }

    final class CaptureView: NSView {
        var onWindow: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window {
                onWindow?(window)
            }
        }
    }
}
