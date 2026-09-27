import Foundation
import Shared

/// App-side blueutil operations: the device list and manual reconnects.
/// The daemon has its own controller; the app runs blueutil only for
/// these user-facing actions. Blocking process work runs off the main
/// actor.
public enum BlueutilRunner {

    /// Paired devices from `blueutil --paired`; empty when blueutil is
    /// missing or its output can't be read.
    public static func pairedDevices() async -> [BlueutilDevice] {
        await Task.detached(priority: .userInitiated) {
            guard let result = runBlocking(arguments: ["--paired"]) else {
                return []
            }
            return BlueutilPairedParser.parse(output: result.output)
        }.value
    }

    /// Reconnects the device — the reverse of the daemon's disconnect.
    public static func connect(to address: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            guard let result = runBlocking(arguments: ["--connect", address]) else {
                throw BlueutilRunnerError.notFound
            }
            guard result.exitCode == 0 else {
                throw BlueutilRunnerError.connectFailed(exitCode: result.exitCode)
            }
        }.value
    }

    /// Runs blueutil by its resolved absolute path; nil when the binary
    /// is missing. `nonisolated` — detached closures call this off the
    /// main actor, and the module defaults to main-actor isolation.
    nonisolated private static func runBlocking(
        arguments: [String]
    ) -> (output: String, exitCode: Int32)? {
        guard let blueutilPath = BlueutilLocator.resolve() else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: blueutilPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(decoding: data, as: UTF8.self), process.terminationStatus)
    }
}
