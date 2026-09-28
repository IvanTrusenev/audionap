import Foundation
import Shared

/// Bluetooth operations through the blueutil binary (MIT).
public struct BluetoothController {
    public init() {}

    /// true/false when blueutil answered; nil when it could not be
    /// launched — the loop treats repeated nils as tool failure, not as
    /// "not connected".
    public func isConnected(to mac: String) -> Bool? {
        let result = runBlueutil(arguments: ["--is-connected", mac])
        return result.map { BlueutilParser.isConnected(output: $0.output) }
    }

    /// Drops the connection; throws when blueutil fails.
    public func disconnect(_ mac: String) throws {
        guard let result = runBlueutil(arguments: ["--disconnect", mac]) else {
            throw BlueutilError.notFound
        }
        guard result.exitCode == 0 else {
            throw BlueutilError.disconnectFailed(exitCode: result.exitCode)
        }
    }

    /// Runs blueutil by its resolved absolute path — launchd's PATH is
    /// minimal and does not include Homebrew; nil when it cannot launch.
    private func runBlueutil(arguments: [String]) -> (output: String, exitCode: Int32)? {
        guard let blueutilPath = BlueutilLocator.resolve() else { return nil }
        guard let result = ProcessRunner.run(executable: blueutilPath, arguments: arguments) else {
            return nil
        }
        return (result.stdout, result.exitCode)
    }
}

enum BlueutilError: Error {
    case disconnectFailed(exitCode: Int32)
    case notFound
}
