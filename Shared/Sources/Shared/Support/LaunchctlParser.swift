/// Parses the output of `launchctl print gui/<uid>/<label>`.
public enum LaunchctlParser {

    /// Returns true when the output reports the service as running.
    /// `xpcproxy` is the spawn window: launchd runs the xpcproxy
    /// trampoline for a few milliseconds right after a bootstrap before
    /// the daemon itself is up — the job is loaded, so the UI must read
    /// it as running rather than flash "stopped".
    public static func isRunning(output: String) -> Bool {
        output.contains("state = running") || output.contains("state = xpcproxy")
    }
}
