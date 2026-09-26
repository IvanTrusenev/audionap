import Testing

@testable import Shared

struct DaemonDecisionTests {

    // MARK: - Disconnect scenarios

    @Test func disconnectsAfterQuietAndIdle() {
        let decision = DaemonDecision.evaluate(
            nowPlaying: false,
            quietSeconds: 3 * 60,  // exactly the threshold for the default 3-minute timeout
            idleSeconds: 3 * 60,
            config: AppConfig()
        )
        #expect(decision == .disconnect(reason: .quietAndIdle))
        #expect(decision.shouldDisconnect)
    }

    @Test func neverDisconnectsWhilePlaying() {
        let decision = DaemonDecision.evaluate(
            nowPlaying: true,
            quietSeconds: 60 * 60,  // an hour of silence doesn't matter
            idleSeconds: 60 * 60,
            config: AppConfig()
        )
        #expect(decision == .stayConnected(reason: .playing))
    }

    @Test func waitsForSilenceWindow() {
        let decision = DaemonDecision.evaluate(
            nowPlaying: false,
            quietSeconds: 2 * 60 + 59,  // one second short of the threshold
            idleSeconds: 60 * 60,
            config: AppConfig()
        )
        #expect(decision == .stayConnected(reason: .silenceTooShort))
    }

    @Test func waitsForIdleWindow() {
        let decision = DaemonDecision.evaluate(
            nowPlaying: false,
            quietSeconds: 60 * 60,
            idleSeconds: 3 * 60 - 1,  // one second short of the idle window
            config: AppConfig()
        )
        #expect(decision == .stayConnected(reason: .idleTooShort))
    }

    @Test func respectsCustomTimeouts() {
        var config = AppConfig()
        config.silenceTimeoutMinutes = 10
        config.inputWindowMinutes = 5

        // Old thresholds — still too early
        let early = DaemonDecision.evaluate(
            nowPlaying: false, quietSeconds: 4 * 60, idleSeconds: 4 * 60, config: config
        )
        #expect(early.shouldDisconnect == false)

        // New thresholds — time to go
        let onTime = DaemonDecision.evaluate(
            nowPlaying: false, quietSeconds: 10 * 60, idleSeconds: 5 * 60, config: config
        )
        #expect(onTime == .disconnect(reason: .quietAndIdle))
    }

    // MARK: - ignoreUserActivity

    @Test func ignoresIdleWindowWhenConfigured() {
        var config = AppConfig()
        config.ignoreUserActivity = true

        // The user just moved the mouse, but we're configured to ignore that
        let decision = DaemonDecision.evaluate(
            nowPlaying: false,
            quietSeconds: 3 * 60,
            idleSeconds: 0,
            config: config
        )
        #expect(decision == .disconnect(reason: .quietAndIdle))
    }
}
