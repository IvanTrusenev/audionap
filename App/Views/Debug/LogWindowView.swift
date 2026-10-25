import SwiftUI

/// The log window: the daemon.log tail, polled every 2 s — no refresh
/// button, the poll is the refresh. Follows the tail only while it is
/// visible; scrolling up freezes the view entirely — new lines are
/// buffered in the reader and applied in one go when the user returns
/// to the bottom. Freezing, not re-rendering, is what keeps a lazy
/// scroll view from nudging by a row when content grows under the
/// reader. When the file holds more than the tail, the top line points
/// at the file itself.
struct LogWindowView: View {
    /// Fronts this window on repeated Logs-button clicks.
    let presenter: WindowPresenter

    @State private var reader = LogReader()
    /// What the window shows — the reader's latest, applied only
    /// while following.
    @State private var displayedLines: [String] = []
    @State private var displayedTruncated = false
    /// Whether the tail is visible. Set by the bottom marker's
    /// appearance inside the lazy stack.
    @State private var followingTail = true
    /// Hover state of the jump button.
    @State private var jumpHovering = false

    private let bottomID = "bottom"

    var body: some View {
        ScrollViewReader { proxy in
            // The anchor both opens the window at the tail and pins
            // it there while new content arrives — no manual scroll
            // can beat it, because a lazy stack never renders a
            // bottom marker before the first scroll.
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if displayedTruncated {
                        // Rendered as the first row: it becomes
                        // visible exactly when the user scrolls to
                        // the top of the tail.
                        Text("log.older")
                            .font(AppTypography.log)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(displayedLines.enumerated()), id: \.offset) { _, line in
                        Text(verbatim: line)
                            .font(AppTypography.log)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .textSelection(.enabled)
                    }
                    // The follow marker: rendered only while the end
                    // of the content is on screen.
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                        .onAppear { followingTail = true }
                        .onDisappear { followingTail = false }
                }
            }
            .defaultScrollAnchor(.bottomLeading)
            .onChange(of: followingTail) {
                if followingTail {
                    apply()
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .task {
                apply()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    reader.refresh()
                    if followingTail {
                        apply()
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !followingTail {
                    jumpButton(proxy: proxy)
                }
            }
        }
        // Minimums, not a hard frame: the window stretches with the
        // user, the scroll area takes whatever it is given.
        .frame(minWidth: 480, minHeight: 240)
        .background(WindowCapture(onWindow: { presenter.capture($0, as: .logs) }))
    }

    /// Moves the reader's latest content into the displayed state.
    private func apply() {
        displayedLines = reader.lines
        displayedTruncated = reader.truncated
    }

    /// The "Jump to Now" affordance, in the Console style: appears
    /// only while the follow is paused, says "you are not at the
    /// tail", and returns to it in one click. Deliberately quiet at
    /// rest — a floating convenience must not compete with the
    /// content — and gains its emphasis on hover.
    private func jumpButton(proxy: ScrollViewProxy) -> some View {
        Button {
            followingTail = true
            apply()
            proxy.scrollTo(bottomID, anchor: .bottom)
        } label: {
            Image(systemName: "arrow.down")
                .font(AppTypography.jumpButtonIcon)
                .foregroundStyle(.secondary)
                .padding(6)
                .background(
                    Circle()
                        .fill(.regularMaterial)
                        .overlay(
                            Circle().strokeBorder(
                                jumpHovering ? Color.primary.opacity(0.2) : .clear,
                                lineWidth: 1)
                        )
                )
                .shadow(radius: jumpHovering ? 4 : 2)
                .scaleEffect(jumpHovering ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .help("log.jumpToTail")
        .onHover { jumpHovering = $0 }
        .padding(.bottom, 8)
        .transition(.opacity)
        .animation(.easeOut(duration: 0.15), value: followingTail)
        .animation(.easeOut(duration: 0.15), value: jumpHovering)
    }
}

#Preview {
    LogWindowView(presenter: WindowPresenter())
        .appTheme(.standard)
}
