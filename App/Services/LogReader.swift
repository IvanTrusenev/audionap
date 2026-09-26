import Foundation
import Observation
import Shared

/// The tail of daemon.log for the menu bar window.
///
/// Reads from the end of the file backwards in chunks, so a log that grows
/// forever never loads fully.
@MainActor
@Observable
public final class LogReader {
    /// Last lines of the log, newest last.
    public private(set) var lines: [String] = []

    private let logURL: URL
    private let lineLimit: Int

    public init(logURL: URL = Paths.daemonLogURL, lineLimit: Int = 15) {
        self.logURL = logURL
        self.lineLimit = lineLimit
    }

    /// Re-reads the tail. A missing file yields no lines — the daemon has
    /// never logged yet — and the view shows an empty state, not an error.
    public func refresh() {
        lines = readTail()
    }

    /// Walks the file backwards: read the last chunk, keep prepending
    /// chunks until `lineLimit` lines are collected or the start is hit.
    private func readTail() -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: logURL) else {
            return []
        }
        defer { try? handle.close() }

        let chunkSize = 8_192
        var offset = (try? handle.seekToEnd()) ?? 0
        var collected = Data()

        while true {
            let readStart = offset >= chunkSize ? offset - UInt64(chunkSize) : 0
            try? handle.seek(toOffset: readStart)
            if let chunk = try? handle.readDataToEndOfFile() {
                collected = chunk + collected
            }
            let result = LogTailParser.lastLines(in: collected, limit: lineLimit)
            if result.count >= lineLimit || readStart == 0 {
                return result
            }
            offset = readStart
        }
    }
}
