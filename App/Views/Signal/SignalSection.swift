import SwiftUI

/// Section 2 of the popup: one slot of a fixed height with two modes —
/// the equalizer while sound reaches the speaker, the silence/idle
/// progress bars otherwise. The switch follows `playing` from the
/// daemon's heartbeat, with a short crossfade so a flapping signal
/// reads as a gentle change, not a flicker. A dead daemon hides the
/// section entirely — ContentView drops it and collapses the
/// dividers.
struct SignalSection: View {
    let bands: [Double]
    let playing: Bool
    let quietSeconds: Int
    let idleSeconds: Int
    let silenceTimeoutSeconds: Int
    let inputWindowSeconds: Int
    /// Whether the daemon ignores user activity — hides the idle block.
    let ignoreIdle: Bool

    var body: some View {
        ZStack {
            if playing {
                EqualizerView(bands: bands)
                    .transition(.opacity)
            } else {
                ProgressBarsView(
                    quietSeconds: quietSeconds,
                    idleSeconds: idleSeconds,
                    silenceTimeoutSeconds: silenceTimeoutSeconds,
                    inputWindowSeconds: inputWindowSeconds,
                    ignoreIdle: ignoreIdle)
                    .transition(.opacity)
            }
        }
        .frame(height: EqualizerView.maxHeight)
        .animation(.easeInOut(duration: 0.25), value: playing)
    }
}

#Preview("Playing") {
    SignalSection(
        bands: [0.8, 0.7, 1.0, 0.75, 0.45, 0.28, 0.16, 0.18,
                0.46, 0.27, 0.6, 0.9, 0.5, 0.4, 0.3, 0.2],
        playing: true,
        quietSeconds: 0,
        idleSeconds: 30,
        silenceTimeoutSeconds: 900,
        inputWindowSeconds: 900,
        ignoreIdle: false)
        .appTheme(.standard)
        .padding()
}

#Preview("Silent") {
    SignalSection(
        bands: Array(repeating: 0, count: 16),
        playing: false,
        quietSeconds: 420,
        idleSeconds: 720,
        silenceTimeoutSeconds: 900,
        inputWindowSeconds: 900,
        ignoreIdle: false)
        .appTheme(.standard)
        .padding()
}
