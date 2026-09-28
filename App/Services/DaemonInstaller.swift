import Foundation
import Shared

/// Provisions the daemon: copies the bundled audionapd into Application
/// Support — the stable path launchd runs — when it is missing or the
/// version marker differs, then restarts a running agent so the new
/// binary takes effect.
@MainActor
public struct DaemonInstaller {
    public init() {}

    /// Installs the bundled daemon when needed; returns true when an
    /// install happened. The file work runs off the main actor.
    public func ensureInstalled() async throws -> Bool {
        try await Task.detached(priority: .userInitiated) {
            try Self.installBlocking()
        }.value
    }

    /// The blocking file work — runs in the detached task, off the actor.
    nonisolated private static func installBlocking() throws -> Bool {
        let installedVersion = (try? String(contentsOf: Paths.daemonVersionURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard DaemonProvisioning.needsInstall(installedVersion: installedVersion) else {
            return false
        }
        // Explicit path: url(forAuxiliaryExecutable:) searches only
        // Contents/MacOS, not Contents/Helpers (verified on macOS 27).
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/audionapd")
        guard FileManager.default.isExecutableFile(atPath: bundled.path) else {
            throw DaemonInstallError.bundledDaemonMissing
        }
        let data = try Data(contentsOf: bundled)
        try FileManager.default.createDirectory(
            at: Paths.appSupportDirectory, withIntermediateDirectories: true)
        try data.write(to: Paths.daemonURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: Paths.daemonURL.path)
        try (AppIdentity.version + "\n").write(
            to: Paths.daemonVersionURL, atomically: true, encoding: .utf8)

        if DaemonController.isAgentRunning() {
            _ = DaemonController.runLaunchctl(
                arguments: ["kickstart", "-k", "gui/\(getuid())/\(DaemonController.label)"])
        }
        return true
    }
}

public enum DaemonInstallError: Error, Sendable {
    case bundledDaemonMissing
}

/// Human-readable messages for the UI; the view shows
/// `error.localizedDescription` and stays unaware of the details.
extension DaemonInstallError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .bundledDaemonMissing:
            String(localized: "error.daemonInstall.bundledMissing")
        }
    }
}
