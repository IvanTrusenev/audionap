import Foundation
import Shared

/// Bluetooth operations through the blueutil binary (MIT).
public struct BluetoothController {
    public init() {}

    /// true when blueutil reports the device as connected.
    public func isConnected(to mac: String) -> Bool {
        let result = runBlueutil(arguments: ["--is-connected", mac])
        return BlueutilParser.isConnected(output: result.output)
    }

    /// Drops the connection; throws when blueutil fails.
    public func disconnect(_ mac: String) throws {
        let result = runBlueutil(arguments: ["--disconnect", mac])
        guard result.exitCode == 0 else {
            if result.exitCode == -1 {
                throw BlueutilError.notFound
            }
            throw BlueutilError.disconnectFailed(exitCode: result.exitCode)
        }
    }

    /// Runs blueutil by its resolved absolute path — launchd's PATH is
    /// minimal and does not include Homebrew; returns output + exit code.
    private func runBlueutil(arguments: [String]) -> (output: String, exitCode: Int32) {
        guard let blueutilPath = BlueutilLocator.resolve() else {
            return ("", -1)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: blueutilPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
        } catch {
            return ("", -1)
        }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        return (String(decoding: data, as: UTF8.self), process.terminationStatus)
    }
}

enum BlueutilError: Error {
    case disconnectFailed(exitCode: Int32)
    case notFound
}
