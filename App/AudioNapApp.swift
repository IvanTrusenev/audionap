import SwiftUI

@main
struct AudioNapApp: App {
    /// Shared between the popup and the settings window: one store, so
    /// a change made in the window shows in the popup instantly, and
    /// one autostart controller, so the launch-at-login toggle reads
    /// the same filesystem truth everywhere.
    @State private var store = ConfigStore()
    @State private var autostart = AutostartController()
    /// Fronts the settings window on repeated clicks — openWindow alone
    /// never re-fronts an existing window.
    @State private var windowPresenter = SettingsWindowPresenter()

    var body: some Scene {
        MenuBarExtra("AudioNap", systemImage: "speaker.wave.2") {
            ContentView(
                store: store,
                autostart: autostart,
                windowPresenter: windowPresenter)
                .appTheme(.standard)
        }
        .menuBarExtraStyle(.window)

        Window("settings.window.title", id: "settings") {
            SettingsWindowView(
                store: store,
                autostart: autostart,
                presenter: windowPresenter)
                .appTheme(.standard)
        }
        .windowResizability(.contentSize)
    }
}
