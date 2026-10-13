import SwiftUI

/// The log window: the daemon.log tail, polled every 2 s — no refresh
/// button, the poll is the refresh. Follows the tail while scrolled
/// to the bottom; scrolling up pauses the follow, returning to the
/// bottom resumes it. When the file holds more than the tail, the top
/// line points at the file itself.
struct LogWindowView: View {
    /// Fronts this window on repeated Logs-button clicks.
    let presenter: WindowPresenter

    @State private var reader = LogReader()
    /// Whether the tail is visible — the only state where new lines
    /// may pull the view along.
    @State private var followingTail = true

    private let bottomID = "bottom"

    var body: some View {
        GeometryReader { outer in
            ScrollViewReader { proxy in
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if reader.truncated {
                            // Rendered as the first row: it becomes
                            // visible exactly when the user scrolls to
                            // the top of the tail.
                            Text("log.older")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        ForEach(Array(reader.lines.enumerated()), id: \.offset) { _, line in
                            Text(verbatim: line)
                                .font(.system(size: 11, design: .monospaced))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .textSelection(.enabled)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id(bottomID)
                    }
                    .background(
                        GeometryReader { content in
                            Color.clear.preference(
                                key: ContentFrameKey.self,
                                value: content.frame(in: .named("logScroll")))
                        }
                    )
                }
                .coordinateSpace(name: "logScroll")
                .onPreferenceChange(ContentFrameKey.self) { frame in
                    // The distance from the content's bottom edge to
                    // the viewport's bottom edge — small means the
                    // tail is on screen.
                    let distance = frame.height + frame.minY - outer.size.height
                    followingTail = distance < 12
                }
                .onChange(of: reader.lines) {
                    if followingTail {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
        }
        // Minimums, not a hard frame: the window stretches with the
        // user, the scroll area takes whatever it is given.
        .frame(minWidth: 480, minHeight: 240)
        .background(WindowCapture(onWindow: { presenter.capture($0, as: .logs) }))
        .task {
            reader.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                reader.refresh()
            }
        }
    }
}

/// The scroll content's frame in the scroll coordinate space — its
/// minY is the (negated) scroll offset.
private struct ContentFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

#Preview {
    LogWindowView(presenter: WindowPresenter())
        .appTheme(.standard)
}
