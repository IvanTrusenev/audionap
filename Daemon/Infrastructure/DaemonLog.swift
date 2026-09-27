import Foundation

/// Timestamped stdout for the daemon log. launchd redirects stdout into
/// daemon.log, so every line printed through here carries the local time —
/// without it a `step:` line says nothing about *when* it happened.
public enum DaemonLog {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    public static func print(_ message: String) {
        Swift.print("\(formatter.string(from: Date())) \(message)")
    }
}
