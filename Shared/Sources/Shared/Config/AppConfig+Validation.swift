import Foundation

extension AppConfig {
    /// Out-of-range values → defaults; returns warnings for the log.
    /// Pure function — easy to test.
    public func normalized() -> NormalizedConfig {
        var copy = self
        var warnings: [String] = []

        if !Self.silenceTimeoutRange.contains(copy.silenceTimeoutMinutes) {
            warnings.append("silenceTimeoutMinutes \(copy.silenceTimeoutMinutes) is outside \(Self.silenceTimeoutRange) — using default")
            copy.silenceTimeoutMinutes = Self.defaultSilenceTimeoutMinutes
        }
        if !Self.inputWindowRange.contains(copy.inputWindowMinutes) {
            warnings.append("inputWindowMinutes \(copy.inputWindowMinutes) is outside \(Self.inputWindowRange) — using default")
            copy.inputWindowMinutes = Self.defaultInputWindowMinutes
        }
        if !Self.pollSecondsRange.contains(copy.pollSeconds) {
            warnings.append("pollSeconds \(copy.pollSeconds) is outside \(Self.pollSecondsRange) — using default")
            copy.pollSeconds = Self.defaultPollSeconds
        }

        return NormalizedConfig(config: copy, warnings: warnings)
    }
}
