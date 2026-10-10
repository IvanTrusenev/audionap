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
    /// The universal playing signal; nil while its capture is not
    /// running — the step falls back to the legacy assertion signal.
    private let systemAudio: SystemAudioMonitor
    /// Per-device gate: whether the speaker is the output target.
    private let speakerGate = SpeakerOutputMonitor()

    /// Consecutive steps where blueutil could not be launched. After the
    /// threshold the daemon exits so launchd's KeepAlive starts a fresh
    /// process — a live daemon whose tool calls silently fail leaves the
    /// speaker unprotected.
    private var blueutilFailures = 0
    /// Steps spent waiting for a reconnect, for the periodic "still
    /// waiting" ping — silence in the log reads as death.
    private var waitingSteps = 0

    private static let blueutilFailureThreshold = 30  // 5 min at a 10 s poll
    private static let waitingPingEvery = 60  // 10 min at a 10 s poll

    public init(config: AppConfig, systemAudio: SystemAudioMonitor) {
        self.config = config
        self.systemAudio = systemAudio
    }

    public func run() {
        var lastStep = Date.distantPast
        while !Self.stop {
            if Date().timeIntervalSince(lastStep) >= Double(config.pollSeconds) {
                step()
                lastStep = Date()
            }
            // Sleep in short slices: SIGTERM only sets `stop` from the
            // signal context — it does not wake the run loop, and a full
            // pollSeconds sleep (10s) lost the race to launchd's 5s
            // exit-timeout, which SIGKILLed the daemon before it ever
            // checked the flag. A 1s slice notices the signal in time
            // and still pumps the main queue where callbacks land.
            CFRunLoopRunInMode(.defaultMode, 1, false)
        }
    }

    private func step() {
        guard let mac = config.speakerMAC, !mac.isEmpty else { return }

        guard let connected = bluetooth.isConnected(to: mac) else {
            blueutilFailures += 1
            if blueutilFailures == 1 {
                DaemonLog.print("blueutil launch failed — counting failures")
            }
            if blueutilFailures == Self.blueutilFailureThreshold {
                // Forensic evidence before the exit: the open-fd count in
                // the line (high → descriptor leak is back; low → different
                // cause) and the full lsof table in a snapshot next to the
                // logs — a dead process can't be autopsied afterwards.
                let fdCount = (try? FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count) ?? -1
                DaemonLog.print(
                    "ERROR: blueutil unreachable for \(Self.blueutilFailureThreshold) steps (open fds: \(fdCount)) — exiting so launchd restarts a fresh process"
                )
                if let lsof = ProcessRunner.run(executable: "/usr/sbin/lsof", arguments: ["-p", String(getpid())]) {
                    try? lsof.stdout.write(
                        to: Paths.daemonBlindnessURL, atomically: true, encoding: .utf8)
                }
                exit(70)
            }
            return
        }
        blueutilFailures = 0

        // After a disconnect there is no connection — nothing to count, nothing to drop.
        guard connected else {
            quietSeconds = 0
            waitingSteps += 1
            if waitingSteps == 1 || waitingSteps.isMultiple(of: Self.waitingPingEvery) {
                DaemonLog.print("waiting for reconnect (step \(waitingSteps))")
            }
            return
        }
        waitingSteps = 0

        // The universal signal wins while its capture runs; the legacy
        // assertion (which folds in the MediaRemote rate) is the fallback.
        // The gate is best-effort: an unobservable speaker reads as "on"
        // so the universal signal alone decides rather than blocking
        // disconnects on a blind gate.
        let playing =
            systemAudio.isPlaying().map { fractionPlaying in
                (speakerGate.isRunning(mac: config.speakerMAC) ?? true)
                    && fractionPlaying
            } ?? assertionSource.isPlayingAudio()
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

        let quietAtDecision = quietSeconds
        if decision.shouldDisconnect {
            try? bluetooth.disconnect(mac)
            quietSeconds = 0
        }

        DaemonLog.print("step: \(decision) quiet=\(quietAtDecision)s idle=\(idleSeconds)s")
    }

    /// Applies a reloaded config — the watcher calls this on the main queue,
    /// the same queue the loop runs on, so no data race is possible.
    /// Silent no-op when the content is unchanged: the watcher fires both an
    /// immediate load at start and directory events for unrelated writes
    /// (the app's own launchagent.plist), which otherwise logged a spurious
    /// "config reloaded" pair on every start.
    public func update(config: AppConfig) {
        guard config != self.config else { return }
        self.config = config
        DaemonLog.print(
            "config reloaded: speaker=\(config.speakerMAC ?? "none") silence=\(config.silenceTimeoutMinutes)m input=\(config.inputWindowMinutes)m ignoreActivity=\(config.ignoreUserActivity)"
        )
    }

    /// Set by the SIGTERM/SIGINT handler from a signal context — hence
    /// `nonisolated(unsafe)`; the loop only reads it between steps.
    public nonisolated(unsafe) static var stop = false
}
