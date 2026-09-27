import Foundation
import Shared

/// Lists paired Bluetooth devices through the blueutil binary — the
/// same source of truth the daemon uses for connections. The blocking
/// process runs off the main actor.
public enum BlueutilDeviceSource {

    /// Paired devices from `blueutil --paired`; empty when blueutil is
    /// missing or its output can't be read.
    public static func pairedDevices() async -> [BlueutilDevice] {
        await Task.detached(priority: .userInitiated) {
            pairedDevicesBlocking()
        }.value
    }

    nonisolated private static func pairedDevicesBlocking() -> [BlueutilDevice] {
        guard let blueutilPath = BlueutilLocator.resolve() else { return [] }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: blueutilPath)
        process.arguments = ["--paired"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
        } catch {
            return []
        }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return BlueutilPairedParser.parse(
            output: String(decoding: data, as: UTF8.self))
    }
}
