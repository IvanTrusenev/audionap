import SwiftUI

/// A settings row with a labeled slider. Slider only binds
/// BinaryFloatingPoint values, so the Int setting travels through an
/// explicit Double bridge; `step: 1` makes the setter fire on whole
/// steps only. The label is built by the caller — this row knows
/// nothing about what it counts. The row and the slider stretch to
/// the full width — a grouped form would otherwise squeeze the slider
/// into the control column.
public struct SettingsSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Int>

    public init(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Int>
    ) {
        self.label = label
        self._value = value
        self.range = range
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
            Slider(
                value: $value,
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The row carries its own vertical air, like
        // SettingsToggleRow's 44 pt: an item never sits tight against
        // the card edge or the hairline.
        .padding(.vertical, 10)
    }
}
