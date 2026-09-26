import Foundation
import Observation
import Shared
import os

/// The app's view of the daemon config: loads it once at launch, persists
/// every change atomically. The daemon's ConfigWatcher picks the file up —
/// changes apply hot, no restart.
@MainActor
@Observable
public final class ConfigStore {
    /// The loaded config — single source of truth for the UI.
    private var config: AppConfig

    public init() {
        config = AppConfig.load(from: Paths.configURL)
    }

    /// Slider value; each write is persisted immediately.
    public var silenceTimeoutMinutes: Int {
        get { config.silenceTimeoutMinutes }
        set {
            config.silenceTimeoutMinutes = newValue
            persist()
        }
    }

    public var inputWindowMinutes: Int {
        get { config.inputWindowMinutes }
        set {
            config.inputWindowMinutes = newValue
            persist()
        }
    }

    private func persist() {
        do {
            try config.save(to: Paths.configURL)
        } catch {
            Self.logger.warning("failed to save config: \(error, privacy: .public)")
        }
    }

    private static let logger = Logger(
        subsystem: AppIdentity.bundleID, category: "config-store")
}
