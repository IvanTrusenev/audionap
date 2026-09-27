import SwiftUI

@main
struct AudioNapApp: App {
    /// The AppKit delegate; SwiftUI owns it and forwards the lifecycle
    /// callbacks (the SwiftUI `App` protocol has no
    /// `applicationDidFinishLaunching`).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("AudioNap", systemImage: "speaker.wave.2") {
            ContentView().appTheme(.standard)
        }
        .menuBarExtraStyle(.window)
    }
}
