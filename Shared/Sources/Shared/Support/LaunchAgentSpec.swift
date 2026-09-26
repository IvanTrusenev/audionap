import Foundation

/// A launchd agent description for the daemon: everything launchd needs to
/// run, keep alive, and log `audionapd`. The `plist` dictionary serializes
/// into the `launchagent.plist` the app installs.
public struct LaunchAgentSpec: Equatable, Sendable {
    /// Unique launchd label (convention: reverse-DNS, matches the plist file name).
    public let label: String
    /// Absolute path to the daemon binary.
    public let programPath: String
    /// Where launchd writes the daemon's stdout.
    public let standardOutPath: String
    /// Where launchd writes the daemon's stderr.
    public let standardErrorPath: String

    public init(
        label: String, programPath: String,
        standardOutPath: String, standardErrorPath: String
    ) {
        self.label = label
        self.programPath = programPath
        self.standardOutPath = standardOutPath
        self.standardErrorPath = standardErrorPath
    }

    /// The launchd property list as a dictionary, ready for serialization.
    public var plist: [String: Any] {
        [
            "Label": label,
            "ProgramArguments": [programPath],
            "KeepAlive": true,
            "StandardOutPath": standardOutPath,
            "StandardErrorPath": standardErrorPath,
        ]
    }

    /// Serialized XML property list, ready to be written to disk.
    public func data() throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }
}
