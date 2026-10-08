import Shared
import SwiftUI

/// Timeout sliders, bridged into `ConfigStore`: every tick is saved, and
/// the daemon hot-reloads the config file (debounced by its ConfigWatcher).
struct SettingsControls: View {
    let store: ConfigStore
    let autostart: AutostartController

    /// Autostart state comes from the filesystem, not memory: the toggle
    /// survives app restarts and stays honest if the file was touched.
    @State private var launchAtLogin = false
    @State private var autostartErrorMessage = ""
    @State private var showingAutostartError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            slider(
                title: String(localized: "settings.silenceTimeout"),
                binding: Binding(
                    get: { Double(store.silenceTimeoutMinutes) },
                    set: { store.silenceTimeoutMinutes = Int($0) }
                ),
                range: AppConfig.silenceTimeoutRange
            )
            slider(
                title: String(localized: "settings.idleWindow"),
                binding: Binding(
                    get: { Double(store.inputWindowMinutes) },
                    set: { store.inputWindowMinutes = Int($0) }
                ),
                range: AppConfig.inputWindowRange
            )
            toggleRow(
                title: "settings.ignoreUserActivity",
                isOn: Binding(
                    get: { store.ignoreUserActivity },
                    set: { store.ignoreUserActivity = $0 }
                )
            )
            toggleRow(
                title: "settings.launchAtLogin",
                isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        Task {
                            do {
                                try await autostart.setEnabled(newValue)
                            } catch {
                                // The filesystem is the truth: re-read it
                                // so the toggle snaps back honestly.
                                launchAtLogin = AutostartController.isEnabled()
                                autostartErrorMessage = error.localizedDescription
                                showingAutostartError = true
                            }
                        }
                    }
                )
            )
        }
        .onAppear {
            launchAtLogin = AutostartController.isEnabled()
        }
        .alert("error.autostart.title", isPresented: $showingAutostartError) {
            Button("action.ok") {}
        } message: {
            Text(autostartErrorMessage)
        }
    }

    /// A settings row: the switch pinned right. A plain Toggle would sit
    /// the control right after the label text, so the label owns the
    /// stretch instead — the Spacer inside it takes the free width and
    /// the switch lands on the trailing edge. `controlSize(.mini)`
    /// matches the compact switches in System Settings; the macOS pill
    /// renders large by default.
    private func toggleRow(
        title: LocalizedStringKey, isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack {
                Text(title)
                Spacer()
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
    }

    /// Labeled slider. Slider only binds BinaryFloatingPoint values, so the
    /// Int setting travels through an explicit Double bridge; `step: 1`
    /// makes the setter fire on whole minutes only. The range comes from
    /// AppConfig — product limits live in one place.
    /// The label is one localized template with two placeholders (title and
    /// minute count), so the word order can differ per language.
    private func slider(
        title: String, binding: Binding<Double>, range: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("settings.timeoutValue \(title) \(Int(binding.wrappedValue))")
            Slider(
                value: binding,
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
        }
    }
}
