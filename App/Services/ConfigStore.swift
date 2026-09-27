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

    /// Minutes of recent user input that keep the speaker connected —
    /// the "input window" of the idle safety net. Persisted on every
    /// write, hot-reloaded by the daemon.
    public var inputWindowMinutes: Int {
        get { config.inputWindowMinutes }
        set {
            config.inputWindowMinutes = newValue
            persist()
        }
    }

    /// The speaker the daemon babysits; nil = none selected. Written by
    /// the device picker, hot-reloaded by the daemon like every setting.
    public var speakerMAC: String? {
        get { config.speakerMAC }
        set {
            config.speakerMAC = newValue
            persist()
        }
    }

    /// When on, the daemon ignores user input and counts only silence
    /// toward the disconnect. Persisted on every write, hot-reloaded.
    public var ignoreUserActivity: Bool {
        get { config.ignoreUserActivity }
        set {
            config.ignoreUserActivity = newValue
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
