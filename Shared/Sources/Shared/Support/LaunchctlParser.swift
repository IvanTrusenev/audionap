/// Parses the output of `launchctl print gui/<uid>/<label>`.
public enum LaunchctlParser {

    /// Returns true when the output reports the service as running.
    public static func isRunning(output: String) -> Bool {
        output.contains("state = running")
    }
}
