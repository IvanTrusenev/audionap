import Foundation

/// Extracts the last N lines from raw log bytes — the pure, testable half
/// of the log-tail feature; the file-reading half lives in the app's
/// `LogReader`.
public enum LogTailParser {

    /// Returns the last `limit` lines of `data`, newest last. A trailing
    /// newline does not produce a trailing empty line; invalid UTF-8 at a
    /// chunk boundary degrades to a replacement character, never a crash.
    public static func lastLines(in data: Data, limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        var lines = String(decoding: data, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        if lines.last == "" {
            lines.removeLast()
        }
        return Array(lines.suffix(limit))
    }
}
