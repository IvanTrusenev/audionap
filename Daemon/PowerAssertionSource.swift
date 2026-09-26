import Foundation
import Shared

/// Source of "is the Chromium family playing": runs `pmset -g assertions`
/// and parses the output with the pure parser.
public struct PowerAssertionSource {
    public init() {}

    /// True while the "Playing audio" assertion is held.
    public func isPlayingAudio() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "assertions"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
        } catch {
            return false   // couldn't launch — don't crash, just report "not playing"
        }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        return PowerAssertionParser.isPlayingAudio(in: output)
    }
}
