import Foundation
import Observation
import Shared

/// The tail of daemon.log for the log window.
///
/// Reads from the end of the file backwards in chunks until roughly
/// `byteLimit` bytes are collected, so a log that grows forever never
/// loads fully. `truncated` reports that earlier entries exist beyond
/// the tail — the window shows the pointer to the file itself.
@MainActor
@Observable
public final class LogReader {
    /// The design's "no pagination" tail.
    private static let byteLimit = 200_000

    /// The tail's lines, newest last, cut at a line boundary.
    public private(set) var lines: [String] = []
    /// True when the file holds more than the tail — earlier entries
    /// exist but are not loaded.
    public private(set) var truncated = false

    private let logURL: URL

    public init(logURL: URL = Paths.daemonLogURL) {
        self.logURL = logURL
    }

    /// Re-reads the tail. A missing file yields no lines — the daemon has
    /// never logged yet — and the window shows an empty state, not an error.
    /// State is assigned only on an actual change: @Observable publishes
    /// on assignment, and a redundant re-render every poll made the
    /// lazy scroll view jitter while the user read older lines.
    public func refresh() {
        let tail = readTail()
        guard tail.lines != lines || tail.truncated != truncated else { return }
        lines = tail.lines
        truncated = tail.truncated
    }

    /// Walks the file backwards through the shared tail reader; the
    /// cut lands mid-line, so the partial first line is dropped.
    private func readTail() -> (lines: [String], truncated: Bool) {
        guard let tail = LogTailReader.readTail(from: logURL, byteLimit: Self.byteLimit)
        else {
            return ([], false)
        }
        let data = LogTailParser.lineAligned(tail.data)
        let lines = LogTailParser.lastLines(in: data, limit: Int.max)
        return (lines, tail.truncated)
    }
}
