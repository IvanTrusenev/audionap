import Foundation
import Observation

/// The log window's presentation model: polls the log tail every 2 s
/// (no refresh button — the poll is the refresh), and follows the
/// tail only while it is visible. Scrolling up freezes the view
/// entirely: new lines are buffered in the reader and applied in one
/// go when the user returns to the bottom.
@MainActor
@Observable
public final class LogWindowViewModel {
    /// How often the tail is re-read — no refresh button, the poll is
    /// the refresh.
    private static let pollInterval: Duration = .seconds(2)

    private let reader = LogReader()

    /// What the window shows — the reader's latest, applied only
    /// while following.
    public private(set) var displayedLines: [String] = []
    public private(set) var displayedTruncated = false
    /// Whether the tail is visible. Set by the bottom marker's
    /// appearance inside the lazy stack.
    public var followingTail = true

    public init() {}

    /// The polling loop — runs for the window's lifetime, the task is
    /// cancelled when the view disappears.
    public func start() async {
        apply()
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.pollInterval)
            reader.refresh()
            if followingTail {
                apply()
            }
        }
    }

    /// Moves the reader's latest content into the displayed state.
    public func apply() {
        displayedLines = reader.lines
        displayedTruncated = reader.truncated
    }
}
