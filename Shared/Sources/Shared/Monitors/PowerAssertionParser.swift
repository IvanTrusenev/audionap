import Foundation

/// Parses the output of `pmset -g assertions`.
public enum PowerAssertionParser {

    /// Returns true when an active `NoIdleSleepAssertion named: "Playing audio"`
    /// is present in the output.
    public static func isPlayingAudio(in output: String) -> Bool {
        output.contains("NoIdleSleepAssertion named: \"Playing audio\"")
    }
}
