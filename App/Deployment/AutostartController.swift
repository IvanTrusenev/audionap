import Foundation
import Shared

/// Manages the LaunchAgents copy of the daemon's launch agent: its
/// presence means launchd starts the daemon at login, without any
/// launchctl calls from the app.
///
/// `@MainActor` — the toggle reads/writes it from the UI.
@MainActor
public struct AutostartController {
    public init() {}

    /// Whether the LaunchAgents copy is in place. The filesystem is the
    /// source of truth — the toggle survives app restarts and stays
    /// honest if the file was touched by hand.
    public static func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: Paths.launchAgentInstalledURL.path)
    }

    /// Installs or removes the copy. Enabling refreshes the canonical
    /// plist first, so the copy always carries current paths. File work
    /// runs off the main actor, keeping the UI responsive.
    public func setEnabled(_ enabled: Bool) async throws {
        try await Task.detached(priority: .userInitiated) {
            try Self.setEnabledBlocking(enabled)
        }.value
    }

    nonisolated private static func setEnabledBlocking(_ enabled: Bool) throws {
        if enabled {
            try DaemonController.writeLaunchAgentPlist()
            try FileManager.default.createDirectory(
                at: Paths.launchAgentInstalledURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: Paths.launchAgentInstalledURL)
            try FileManager.default.copyItem(
                at: Paths.launchAgentTemplateURL,
                to: Paths.launchAgentInstalledURL)
        } else {
            try? FileManager.default.removeItem(at: Paths.launchAgentInstalledURL)
        }
    }
}
