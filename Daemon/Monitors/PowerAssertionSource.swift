import Foundation
import Shared

/// Source of "is the Chromium family playing": runs `pmset -g assertions`
/// and parses the output with the pure parser.
public struct PowerAssertionSource: PlaybackSource {
    public init() {}

    /// True while the "Playing audio" assertion is held.
    public func isPlayingAudio() -> Bool {
        guard let result = ProcessRunner.run(
            executable: "/usr/bin/pmset",
            arguments: ["-g", "assertions"]
        ) else {
            return false  // couldn't launch — don't crash, just report "not playing"
        }
        return PowerAssertionParser.isPlayingAudio(in: result.stdout)
    }
}
