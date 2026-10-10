import ArgumentParser
import Foundation
import Shared

/// The AudioNap daemon: watches playback (MediaRemote + power assertions) and
/// user inactivity, and drops the Bluetooth connection to the configured
/// speaker after N minutes of silence — the speaker's own power-off timer
/// finishes the job. Runs as a launchd agent, but also answers
/// `--test-once` for a single detection pass.
@main
struct AudioNapDaemon: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "audionapd",
        abstract: "Disconnects a Bluetooth speaker after silence and inactivity.",
        version: AppIdentity.version
    )

    @Flag(help: "Run one detection pass and print the result. Never disconnects.")
    var testOnce = false

    func run() throws {
        if testOnce {
            let mac = ProcessInfo.processInfo.environment["AUDIONAP_SPEAKER_MAC"] ?? "aa-bb-cc-dd-ee-ff"
            guard let connected = BluetoothController().isConnected(to: mac) else {
                print("connected: unknown (blueutil unreachable)")
                return
            }
            print("connected: \(connected)")

            guard connected else {
                return
            }

            let assertion = PowerAssertionSource().isPlayingAudio()
            let idle = IdleMonitor().idleSeconds()
            print("assertion: \(assertion)")
            print("idle: \(Int(idle))s")
            return
        }

        // Main loop: hot config via the watcher, clean exit via signals.
        signal(SIGTERM) { _ in DaemonLoop.stop = true }
        signal(SIGINT) { _ in DaemonLoop.stop = true }

        // launchd redirects stdout into daemon.log; a file pipe buffers
        // blocks, so unbuffer per line or the log looks dead.
        setvbuf(stdout, nil, _IOLBF, 0)

        let systemAudio = SystemAudioMonitor()
        Task {
            // The capture is best-effort: without the permission or on
            // stream errors the monitor stays down and the loop keeps
            // working on the legacy playing signals.
            do {
                try await systemAudio.start()
            } catch {
                DaemonLog.print(
                    "audio capture: unavailable — legacy playing signals (\(String(describing: error)))")
            }
        }

        let loop = DaemonLoop(
            config: AppConfig.load(from: Paths.configURL),
            systemAudio: systemAudio)
        let watcher = ConfigWatcher()
        watcher.start { newConfig in
            loop.update(config: newConfig)
        }

        loop.run()
        // Best-effort cleanup — the capture dies with the process anyway.
        Task { await systemAudio.stop() }
        // A marker in the log that the daemon exited on its own — a
        // SIGKILL from launchd's exit-timeout leaves no such line.
        DaemonLog.print("stopped cleanly")
    }
}
