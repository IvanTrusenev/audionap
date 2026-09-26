import Foundation

/// Source of "is audio playing now". The daemon combines several sources:
/// the final formula is `assertion("Playing audio") || mediaRemotePlaying`.
public protocol PlaybackSource: Sendable {
    func isPlayingAudio() -> Bool
}
