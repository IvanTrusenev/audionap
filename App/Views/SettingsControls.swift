import Shared
import SwiftUI

/// Timeout sliders, bridged into `ConfigStore`: every tick is saved, and
/// the daemon hot-reloads the config file (debounced by its ConfigWatcher).
struct SettingsControls: View {
    let store: ConfigStore

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
        }
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
