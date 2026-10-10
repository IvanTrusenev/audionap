import SwiftUI

/// The equalizer strip: one bar per frequency band, height = band
/// level. Live audio makes the bars dance; silence and a stopped
/// daemon read as a flat line — the state is the truth.
struct EqualizerView: View {
    let bands: [Double]

    @Environment(\.appTheme) private var theme

    /// Bar geometry: twice the old strip, built from VU-meter bricks —
    /// 9 segments × 4 pt with 1 pt gaps fill 44 pt exactly.
    private static let maxHeight: CGFloat = 44
    private static let segmentCount = 9
    private static let segmentHeight: CGFloat = 4
    private static let segmentGap: CGFloat = 1

    var body: some View {
        // The "window and shutter" model: a fixed full-height gradient
        // (VU-meter green → amber → red) behind the bars; each bar's
        // visible bricks mask the bottom of it, so low bars reveal
        // green and tall bars reach the red tip. The gradient stays
        // anchored to the strip — never stretched to a bar's own
        // bounds. Bars span the window width with a gap of half a bar
        // (EqualizerLayout).
        theme.equalizerBar
            .frame(height: Self.maxHeight)
            .mask(alignment: .bottom) {
                EqualizerLayout {
                    ForEach(bands.indices, id: \.self) { index in
                        bar(level: bands[index])
                    }
                }
                .frame(height: Self.maxHeight, alignment: .bottom)
            }
            .frame(height: Self.maxHeight, alignment: .bottom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeOut(duration: 0.1), value: bands)
    }

    /// A bar of VU-meter bricks: the bottom `filled` segments are
    /// visible, the rest transparent — at least one brick stays lit in
    /// silence so the strip never vanishes. Segment indices count from
    /// the top, so the visible range is the tail of the list.
    private func bar(level: Double) -> some View {
        let filled = max(1, Int((level * Double(Self.segmentCount)).rounded()))
        return VStack(spacing: Self.segmentGap) {
            ForEach(0..<Self.segmentCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index >= Self.segmentCount - filled ? .white : .clear)
                    .frame(height: Self.segmentHeight)
            }
        }
        .frame(height: Self.maxHeight, alignment: .bottom)
    }

    /// Places the bars across the full width with a gap of half a bar:
    /// 31 bars at 2:1 ratio fill the window exactly.
    private struct EqualizerLayout: Layout {
        static let gapFraction = 0.5

        func sizeThatFits(
            proposal: ProposedViewSize,
            subviews: Subviews,
            cache: inout ()
        ) -> CGSize {
            CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
        }

        func placeSubviews(
            in bounds: CGRect,
            proposal: ProposedViewSize,
            subviews: Subviews,
            cache: inout ()
        ) {
            let units = Double(subviews.count) + Double(subviews.count - 1) * Self.gapFraction
            let barWidth = bounds.width / units
            var x = bounds.minX
            for subview in subviews {
                subview.place(
                    at: CGPoint(x: x, y: bounds.maxY),
                    anchor: .bottomLeading,
                    proposal: ProposedViewSize(
                        width: barWidth, height: bounds.height))
                x += barWidth * (1 + Self.gapFraction)
            }
        }
    }
}

#Preview("Live bands") {
    EqualizerView(bands: [
        0.8, 0.7, 1.0, 0.75, 0.45, 0.28, 0.16, 0.18,
        0.46, 0.27, 0.6, 0.9, 0.5, 0.4, 0.3, 0.2,
    ])
        .appTheme(.standard)
        .padding()
}

#Preview("Silence") {
    EqualizerView(bands: Array(repeating: 0, count: 16))
        .appTheme(.standard)
        .padding()
}
