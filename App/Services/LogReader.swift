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
    public func refresh() {
        let tail = readTail()
        lines = tail.lines
        truncated = tail.truncated
    }

    /// Walks the file backwards: read the last chunk, keep prepending
    /// chunks until `byteLimit` bytes are collected or the start is hit.
    private func readTail() -> (lines: [String], truncated: Bool) {
        guard let handle = try? FileHandle(forReadingFrom: logURL) else {
            return ([], false)
        }
        defer { try? handle.close() }

        let chunkSize = 8_192
        var offset = (try? handle.seekToEnd()) ?? 0
        var collected = Data()

        while true {
            let readStart = offset >= chunkSize ? offset - UInt64(chunkSize) : 0
            try? handle.seek(toOffset: readStart)
            let chunk = handle.readDataToEndOfFile()
            collected = chunk + collected
            guard collected.count >= Self.byteLimit || readStart == 0 else {
                offset = readStart
                continue
            }

            var data = Data(collected.suffix(Self.byteLimit))
            // The cut lands mid-line; drop the partial first line so
            // the window starts clean at a line boundary.
            if let newline = data.firstIndex(of: 0x0A) {
                data = data.subdata(in: (newline + 1)..<data.count)
            }
            let lines = LogTailParser.lastLines(in: data, limit: Int.max)
            return (lines, truncated: offset > 0)
        }
    }
}
