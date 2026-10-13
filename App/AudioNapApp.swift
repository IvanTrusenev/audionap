import SwiftUI

@main
struct AudioNapApp: App {
    /// Shared between the popup and the settings window: one store, so
    /// a change made in the window shows in the popup instantly, and
    /// one autostart controller, so the launch-at-login toggle reads
    /// the same filesystem truth everywhere.
    @State private var store = ConfigStore()
    @State private var autostart = AutostartController()

    var body: some Scene {
        MenuBarExtra("AudioNap", systemImage: "speaker.wave.2") {
            ContentView(store: store, autostart: autostart)
                .appTheme(.standard)
        }
        .menuBarExtraStyle(.window)

        Window("settings.window.title", id: "settings") {
            SettingsWindowView(store: store, autostart: autostart)
                .appTheme(.standard)
        }
        .windowResizability(.contentSize)
    }
}
