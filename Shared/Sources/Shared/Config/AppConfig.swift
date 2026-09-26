import Foundation

/// Daemon configuration. Stored at
/// `~/Library/Application Support/AudioNap/config.plist`.
///
/// Rules from the plan: unknown keys are tolerated (ignored), invalid values
/// fall back to defaults with a log warning — never crash.
public struct AppConfig: Codable, Equatable, Sendable {
    /// Speaker MAC in blueutil format (`aa-bb-cc-dd-ee-ff`).
    public var speakerMAC: String?
    public var silenceTimeoutMinutes: Int
    public var inputWindowMinutes: Int
    public var ignoreUserActivity: Bool
    /// Requirement: disconnect only while the speaker runs on battery —
    /// a speaker on wall power is never disconnected.
    public var speakerOnBattery: Bool
    public var pollSeconds: Int
    /// Path to `blueutil`; nil = search PATH.
    public var blueutilPath: String?
    /// Path to the optional `nowplaying-cli` fallback; nil = don't use it.
    public var nowPlayingCLIPath: String?
    public var logLevel: LogLevel

    public static let silenceTimeoutRange = 1...30
    public static let inputWindowRange = 1...30
    public static let pollSecondsRange = 10...120

    /// Defaults — single source of truth: the init, the forgiving decode, and
    /// normalization all reference these so values can't drift apart.
    public static let defaultSilenceTimeoutMinutes = 3
    public static let defaultInputWindowMinutes = 3
    public static let defaultPollSeconds = 30
    public static let defaultLogLevel: LogLevel = .info
    public static let defaultSpeakerOnBattery = true

    /// The same windows in seconds — the units the daemon counts in.
    /// The only place where minutes are converted to seconds.
    public var silenceTimeoutSeconds: Int { silenceTimeoutMinutes * 60 }
    public var inputWindowSeconds: Int { inputWindowMinutes * 60 }

    public init(
        speakerMAC: String? = nil,
        silenceTimeoutMinutes: Int = Self.defaultSilenceTimeoutMinutes,
        inputWindowMinutes: Int = Self.defaultInputWindowMinutes,
        ignoreUserActivity: Bool = false,
        speakerOnBattery: Bool = Self.defaultSpeakerOnBattery,
        pollSeconds: Int = Self.defaultPollSeconds,
        blueutilPath: String? = nil,
        nowPlayingCLIPath: String? = nil,
        logLevel: LogLevel = Self.defaultLogLevel
    ) {
        self.speakerMAC = speakerMAC
        self.silenceTimeoutMinutes = silenceTimeoutMinutes
        self.inputWindowMinutes = inputWindowMinutes
        self.ignoreUserActivity = ignoreUserActivity
        self.speakerOnBattery = speakerOnBattery
        self.pollSeconds = pollSeconds
        self.blueutilPath = blueutilPath
        self.nowPlayingCLIPath = nowPlayingCLIPath
        self.logLevel = logLevel
    }

    /// Forgiving decode: missing keys → field defaults. The synthesized
    /// Codable would require every key, but the config may be written by an
    /// older app version or by hand.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        speakerMAC = try container.decodeIfPresent(String.self, forKey: .speakerMAC)
        silenceTimeoutMinutes =
            try container.decodeIfPresent(Int.self, forKey: .silenceTimeoutMinutes) ?? Self.defaultSilenceTimeoutMinutes
        inputWindowMinutes =
            try container.decodeIfPresent(Int.self, forKey: .inputWindowMinutes) ?? Self.defaultInputWindowMinutes
        ignoreUserActivity = try container.decodeIfPresent(Bool.self, forKey: .ignoreUserActivity) ?? false
        speakerOnBattery =
            try container.decodeIfPresent(Bool.self, forKey: .speakerOnBattery) ?? Self.defaultSpeakerOnBattery
        pollSeconds = try container.decodeIfPresent(Int.self, forKey: .pollSeconds) ?? Self.defaultPollSeconds
        blueutilPath = try container.decodeIfPresent(String.self, forKey: .blueutilPath)
        nowPlayingCLIPath = try container.decodeIfPresent(String.self, forKey: .nowPlayingCLIPath)
        logLevel = try container.decodeIfPresent(LogLevel.self, forKey: .logLevel) ?? Self.defaultLogLevel
    }
}
