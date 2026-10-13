import Foundation

/// The daemon's log format: local date-time, a category prefix, the
/// message. Categories group events by type so a glance filters the
/// noise; the fixed-width prefix keeps messages aligned. launchd
/// redirects stdout into daemon.log, so nothing but these lines may
/// print.
public enum DaemonLog {
    public enum Category: String {
        /// Normal state — playing, waiting, counting.
        case ok = "[ok]"
        /// An action taken — the disconnect itself.
        case act = "[act]"
        /// Config changes.
        case cfg = "[cfg]"
        /// Capture status — the universal signal's life.
        case cap = "[cap]"
        /// Failures and degradations.
        case warn = "[warn]"
        /// Clean shutdown.
        case bye = "[bye]"
    }

    public static func print(_ category: Category, _ message: String) {
        Swift.print("\(timestamp())  \(prefix(category)) \(message)")
    }

    /// "yyyy-MM-dd HH:mm:ss" in local time, locale-pinned so the
    /// separators never change per language. Built per call on
    /// purpose: lines come from several threads (the capture queue
    /// included), and a shared DateFormatter would need locking for a
    /// handful of lines per minute.
    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }

    /// Padded to six so [ok]/[bye] align with [cfg]/[warn] — the
    /// mockup's column look.
    private static func prefix(_ category: Category) -> String {
        category.rawValue.padding(toLength: 6, withPad: " ", startingAt: 0)
    }
}
