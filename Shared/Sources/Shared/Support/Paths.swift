import Foundation

/// File system locations of the product — answers "where we are"
/// (identity lives in `AppIdentity`). Single source of truth: the app,
/// the daemon, and launchd all resolve their files from here.
public enum Paths {

    /// Base directory in Application Support — everything the app owns lives here.
    public static let appSupportDirectory: URL =
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first!
        .appendingPathComponent("AudioNap")

    /// Daemon configuration (`config.plist`).
    public static let configURL: URL =
        appSupportDirectory.appendingPathComponent("config.plist")

    /// The installed copy of the daemon binary that launchd runs —
    /// a stable location that survives app updates.
    public static let daemonURL: URL =
        appSupportDirectory.appendingPathComponent("audionapd")

    /// Version marker next to the installed daemon: contains
    /// `AppIdentity.version` of the copy that was installed last.
    public static let daemonVersionURL: URL =
        appSupportDirectory.appendingPathComponent("audionapd.version")

    /// Live state for the UI: playing, quiet seconds, connection status.
    public static let stateURL: URL =
        appSupportDirectory.appendingPathComponent("state.plist")

    /// Canonical launchd plist kept in Application Support; a copy in
    /// `~/Library/LaunchAgents/` (see `launchAgentInstalledURL`) enables autostart.
    public static let launchAgentTemplateURL: URL =
        appSupportDirectory.appendingPathComponent("launchagent.plist")

    /// The plist in `~/Library/LaunchAgents/` — its presence means autostart
    /// is on; the file name is the launchd label, derived from the bundle ID.
    public static let launchAgentInstalledURL: URL =
        FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library")
        .appendingPathComponent("LaunchAgents")
        .appendingPathComponent("\(AppIdentity.bundleID).daemon.plist")

    /// Daemon logs directory.
    public static let logsDirectory: URL =
        FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library")
        .appendingPathComponent("Logs")
        .appendingPathComponent("AudioNap")

    public static let daemonLogURL: URL =
        logsDirectory.appendingPathComponent("daemon.log")

    public static let daemonErrorLogURL: URL =
        logsDirectory.appendingPathComponent("daemon-error.log")

    /// Forensic snapshot written right before the daemon exits on a blueutil
    /// failure streak — the open-descriptor table of the dying process.
    public static let daemonBlindnessURL: URL =
        logsDirectory.appendingPathComponent("daemon-blindness.txt")
}
