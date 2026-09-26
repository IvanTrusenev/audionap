import Foundation
import Shared

/// The daemon's main loop: polls sources every `pollSeconds`, counts
/// consecutive silence, and disconnects when DaemonDecision says so.
/// Runs until SIGTERM/SIGINT sets `stop`.
public final class DaemonLoop {
    private var config: AppConfig
    private var quietSeconds = 0
    private let assertionSource = PowerAssertionSource()
    private let idleMonitor = IdleMonitor()
    private let bluetooth = BluetoothController()

    public init(config: AppConfig) {
        self.config = config
    }

    public func run() {
        while !Self.stop {
            step()
            // C API imports without labels; pumps the main queue where
            // system callbacks are delivered, sleeping for pollSeconds.
            CFRunLoopRunInMode(.defaultMode, Double(config.pollSeconds), false)
        }
    }

    private func step() {
        guard let mac = config.speakerMAC, !mac.isEmpty else { return }

        // After a disconnect there is no connection — nothing to count, nothing to drop.
        guard bluetooth.isConnected(to: mac) else {
            quietSeconds = 0
            return
        }

        let playing = assertionSource.isPlayingAudio()
        let idleSeconds = Int(idleMonitor.idleSeconds())

        if playing {
            quietSeconds = 0
        } else {
            quietSeconds += config.pollSeconds
        }

        let decision = DaemonDecision.evaluate(
            nowPlaying: playing,
            quietSeconds: quietSeconds,
            idleSeconds: idleSeconds,
            config: config
        )

        if decision.shouldDisconnect {
            try? bluetooth.disconnect(mac)
            quietSeconds = 0
        }

        print("step: \(decision) quiet=\(quietSeconds)s idle=\(idleSeconds)s")
    }

    /// Applies a reloaded config — the watcher calls this on the main queue,
    /// the same queue the loop runs on, so no data race is possible.
    public func update(config: AppConfig) {
        self.config = config
        print(
            "config reloaded: silence=\(config.silenceTimeoutMinutes)m input=\(config.inputWindowMinutes)m"
        )
    }

    /// Set by the SIGTERM/SIGINT handler from a signal context — hence
    /// `nonisolated(unsafe)`; the loop only reads it between steps.
    public nonisolated(unsafe) static var stop = false
}
