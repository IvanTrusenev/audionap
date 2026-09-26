import Foundation

/// Daemon log level. Stored in the config as a string
/// (`debug`/`info`/`warn`/`error`) — hence the `String` raw value.
public enum LogLevel: String, Codable, CaseIterable, Sendable {
    case debug
    case info
    case warn
    case error

    /// Unknown strings in the plist must not break the config —
    /// fall back to `.info`.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = LogLevel(rawValue: raw) ?? .info
    }
}
