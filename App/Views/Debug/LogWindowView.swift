import SwiftUI

/// The log window: the daemon.log tail, polled every 2 s — no refresh
/// button, the poll is the refresh. Follows the tail only while it is
/// visible; scrolling up freezes the view entirely — new lines are
/// buffered in the reader and applied in one go when the user returns
/// to the bottom. Freezing, not re-rendering, is what keeps a lazy
/// scroll view from nudging by a row when content grows under the
/// reader. When the file holds more than the tail, the top line points
/// at the file itself. The follow logic lives in
/// LogWindowViewModel; this view only renders and scrolls.
struct LogWindowView: View {
    /// Fronts this window on repeated Logs-button clicks.
    let presenter: WindowPresenter

    @State private var vm = LogWindowViewModel()
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
                    if vm.displayedTruncated {
                        // Rendered as the first row: it becomes
                        // visible exactly when the user scrolls to
                        // the top of the tail.
                        Text("log.older")
                            .font(AppTypography.log)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(vm.displayedLines.enumerated()), id: \.offset) { _, line in
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
                        .onAppear { vm.followingTail = true }
                        .onDisappear { vm.followingTail = false }
                }
            }
            .defaultScrollAnchor(.bottomLeading)
            .onChange(of: vm.followingTail) {
                // Follow resumed (scrolled to the tail or jumped):
                // flush the buffered lines and land on the tail.
                if vm.followingTail {
                    vm.apply()
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .onChange(of: vm.displayedLines) {
                // The poll applied new lines while following — stay
                // pinned to the tail.
                if vm.followingTail {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .task {
                await vm.start()
            }
            .overlay(alignment: .bottom) {
                if !vm.followingTail {
                    jumpButton(proxy: proxy)
                }
            }
        }
        // Minimums, not a hard frame: the window stretches with the
        // user, the scroll area takes whatever it is given.
        .frame(minWidth: 480, minHeight: 240)
        .background(WindowCapture(onWindow: { presenter.capture($0, as: .logs) }))
    }

    /// The "Jump to Now" affordance, in the Console style: appears
    /// only while the follow is paused, says "you are not at the
    /// tail", and returns to it in one click. Deliberately quiet at
    /// rest — a floating convenience must not compete with the
    /// content — and gains its emphasis on hover.
    private func jumpButton(proxy: ScrollViewProxy) -> some View {
        Button {
            vm.followingTail = true
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
        .animation(.easeOut(duration: 0.15), value: vm.followingTail)
        .animation(.easeOut(duration: 0.15), value: jumpHovering)
    }
}

#Preview {
    LogWindowView(presenter: WindowPresenter())
        .appTheme(.standard)
}
