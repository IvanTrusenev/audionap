import Foundation

/// The daemon main loop's decision: drop the BT connection or keep it.
/// A pure type with no outside world — the core we cover with unit tests.
public enum DaemonDecision: Equatable, Sendable {
    case stayConnected(reason: StayReason)
    case disconnect(reason: DisconnectReason)

    public enum StayReason: String, Sendable {
        case playing
        case speakerOnPower
        case idleTooShort
        case silenceTooShort
    }

    public enum DisconnectReason: String, Sendable {
        case quietAndIdle
    }

    public var shouldDisconnect: Bool {
        if case .disconnect = self { return true }
        return false
    }

    /// Formula from research:
    /// `disconnect = !playing && idle ≥ inputWindow && quiet ≥ silenceTimeout`
    ///
    /// - Parameters:
    ///   - nowPlaying: audio is playing (MediaRemote or the "Playing audio" assertion)
    ///   - quietSeconds: consecutive seconds of silence
    ///   - idleSeconds: seconds since last user input
    public static func evaluate(
        nowPlaying: Bool,
        quietSeconds: Int,
        idleSeconds: Int,
        config: AppConfig
    ) -> DaemonDecision {
        // Playback is an absolute stop: never cut the music.
        if nowPlaying {
            return .stayConnected(reason: .playing)
        }

        // Requirement: a speaker on wall power is never disconnected —
        // the whole point is saving its battery.
        if !config.speakerOnBattery {
            return .stayConnected(reason: .speakerOnPower)
        }

        // Inactivity is a safety net for apps with no playback signals
        // (Zoom, games): while the user is moving the mouse — don't disconnect.
        if !config.ignoreUserActivity && idleSeconds < config.inputWindowSeconds {
            return .stayConnected(reason: .idleTooShort)
        }

        // Silence itself: wait for the full window.
        if quietSeconds < config.silenceTimeoutSeconds {
            return .stayConnected(reason: .silenceTooShort)
        }

        return .disconnect(reason: .quietAndIdle)
    }
}
