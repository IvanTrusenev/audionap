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
        version: "0.1.0"
    )

    @Flag(help: "Run one detection pass and print the result. Never disconnects.")
    var testOnce = false

    func run() throws {
        if testOnce {
            let playing = PowerAssertionSource().isPlayingAudio()
            let idle = IdleMonitor().idleSeconds()
            print("playing: \(playing)")
            print("idle: \(Int(idle))s")
            return
        }
        
        print("daemon loop: not implemented yet (M2.5)")
    }
}
