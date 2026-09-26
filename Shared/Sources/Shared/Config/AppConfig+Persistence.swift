import Foundation
import os

extension AppConfig {
    public static func load(from url: URL) -> AppConfig {
        let logger = Logger(subsystem: AppIdentity.bundleID, category: "config")
        do {
            let data = try Data(contentsOf: url)
            let decoded = try PropertyListDecoder().decode(AppConfig.self, from: data)
            let normalized = decoded.normalized()
            for warning in normalized.warnings {
                logger.warning("\(warning, privacy: .public)")
            }
            return normalized.config
        } catch {
            // Unreadable/corrupted plist — fall back to defaults, never crash.
            logger.error("failed to read config at \(url.path, privacy: .public): \(error, privacy: .public) — using defaults")
            return AppConfig()
        }
    }

    /// Atomic write: replace the file without leaving a half-written one behind.
    public func save(to url: URL) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(self)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}
