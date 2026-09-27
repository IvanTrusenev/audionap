import SwiftUI

/// The tail of daemon.log plus a refresh button.
struct LogSection: View {
    let reader: LogReader

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("log.title").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("action.refresh") { reader.refresh() }
            }
            if reader.lines.isEmpty {
                Text("log.empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // One Text per line: a single multi-line Text with
                // lineLimit(1) would collapse the whole block to one line.
                // Index-based id — log lines may repeat verbatim. Lines
                // keep their full width (fixedSize) and scroll horizontally
                // instead of truncating; anchored right, where the newest
                // step counters are.
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(reader.lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .textSelection(.enabled)
                        }
                    }
                }
                .defaultScrollAnchor(.trailing)
            }
        }
    }
}
