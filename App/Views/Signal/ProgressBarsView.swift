import SwiftUI

/// The silence/idle progress bars — variant B of the design: label
/// left, elapsed/limit time right, the bar on the full width below.
/// Two blocks: silence fills toward `silenceTimeoutSeconds`, user
/// inactivity toward `inputWindowSeconds`; both counters walk toward
/// the daemon's disconnect decision, so the fill reads as attention.
struct ProgressBarsView: View {
    let quietSeconds: Int
    let idleSeconds: Int
    let silenceTimeoutSeconds: Int
    let inputWindowSeconds: Int

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            block(
                label: "progress.quiet",
                seconds: quietSeconds,
                limit: silenceTimeoutSeconds)
            block(
                label: "progress.idle",
                seconds: idleSeconds,
                limit: inputWindowSeconds)
        }
    }

    private func block(
        label: LocalizedStringKey,
        seconds: Int,
        limit: Int
    ) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(verbatim: "\(Self.time(seconds)) / \(Self.time(limit))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.equalizerAmber.opacity(0.25))
                    Capsule()
                        .fill(theme.equalizerAmber)
                        .frame(width: proxy.size.width * fraction(seconds, limit))
                }
            }
            .frame(height: 5)
        }
    }

    private func fraction(_ seconds: Int, _ limit: Int) -> Double {
        guard limit > 0 else { return 0 }
        return min(1, Double(seconds) / Double(limit))
    }

    /// The mockup's "7:00 / 15:00" shape.
    private static func time(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

#Preview {
    ProgressBarsView(
        quietSeconds: 420,
        idleSeconds: 720,
        silenceTimeoutSeconds: 900,
        inputWindowSeconds: 900)
        .appTheme(.standard)
        .padding()
}
