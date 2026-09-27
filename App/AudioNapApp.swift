import SwiftUI

@main
struct AudioNapApp: App {
    var body: some Scene {
        MenuBarExtra("AudioNap", systemImage: "speaker.wave.2") {
            ContentView()
                .appTheme(.standard)
        }
        .menuBarExtraStyle(.window)
    }
}
