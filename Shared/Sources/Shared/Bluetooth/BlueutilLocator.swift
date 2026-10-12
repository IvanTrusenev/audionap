import Foundation

/// Resolves the absolute path of the `blueutil` binary, independent of the
/// current PATH. launchd runs agents with a minimal PATH
/// (`/usr/bin:/bin:/usr/sbin:/sbin`), so Homebrew's `/opt/homebrew/bin`
/// and `/usr/local/bin` are checked explicitly first.
public enum BlueutilLocator {

    /// Standard install prefixes, most common first: Homebrew on
    /// Apple Silicon, Homebrew on Intel, MacPorts.
    public static let candidateDirectories = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/opt/local/bin",
    ]

    /// Absolute path to blueutil, or nil when it is not installed anywhere
    /// discoverable. Prefixes win over the PATH to survive launchd's
    /// minimal environment; `prefixes` is injectable for hermetic tests.
    public static func resolve(
        in path: String,
        prefixes: [String] = candidateDirectories
    ) -> String? {
        let name = "blueutil"
        var candidates = prefixes.map { "\($0)/\(name)" }
        candidates += path.split(separator: ":").map { "\($0)/\(name)" }
        return candidates.first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }

    /// Resolves against the current process PATH.
    public static func resolve() -> String? {
        resolve(in: ProcessInfo.processInfo.environment["PATH"] ?? "")
    }
}
