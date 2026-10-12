import Foundation

/// Parses the output of `blueutil --is-connected <mac>`: "1" or "0".
public enum BlueutilParser {

    /// Returns true when the trimmed output is "1".
    public static func isConnected(output: String) -> Bool {
        output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }
}
