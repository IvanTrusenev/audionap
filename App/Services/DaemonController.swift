import Foundation
import Observation
import Shared

/// Controls the launchd agent: status/start/stop through `/bin/launchctl`.
///
/// `@MainActor` — the view model lives on the main actor (UI reads it);
/// `@Observable` — SwiftUI observes its properties and re-renders on change.
@MainActor
@Observable
public final class DaemonController {
    public private(set) var isRunning = false

    /// launchd label: online.threealab.audionap.daemon (matches the plist file name).
    private var label: String { AppIdentity.bundleID + ".daemon" }
    /// launchd domain: gui/<uid> — the user's login session.
    private var domain: String { "gui/\(getuid())" }

    public init() {}

    /// Queries launchd and updates `isRunning`.
    public func refreshStatus() {
        let result = runLaunchctl(arguments: ["print", "\(domain)/\(label)"])
        isRunning = LaunchctlParser.isRunning(output: result.output)
    }

    /// Start: write the canonical plist, then (re)bootstrap the agent.
    /// bootout first is required — bootstrap fails with exit code 5 while
    /// a previous instance of the service is still in the domain.
    public func start() throws {
        try writeLaunchAgentPlist()

        _ = runLaunchctl(arguments: ["bootout", "\(domain)/\(label)"])
        let exitCode = bootstrapWithRetry()
        if exitCode != 0 {
            // A retry can land on the far side of the race: bootstrap may
            // have failed while the job actually loaded. Trust launchd.
            refreshStatus()
            if !isRunning {
                throw DaemonControlError.bootstrapFailed(exitCode: exitCode)
            }
        }
        refreshStatus()
    }

    /// bootout removes the service from the domain asynchronously, so a
    /// bootstrap issued right after can hit the half-removed record and
    /// fail with exit code 5. Retry until `deadline` — launchd's exit
    /// timeout (5s for this job) bounds the teardown — and report the
    /// last exit code.
    private func bootstrapWithRetry() -> Int32 {
        let deadline = Date().addingTimeInterval(5)
        var exitCode: Int32 = -1
        repeat {
            exitCode = runLaunchctl(arguments: [
                "bootstrap", domain, Paths.launchAgentTemplateURL.path,
            ]).exitCode
            if exitCode == 0 {
                return 0
            }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return exitCode
    }

    /// Stop: bootout the agent.
    public func stop() throws {
        let result = runLaunchctl(arguments: ["bootout", "\(domain)/\(label)"])
        // exit code 3 = "No such process": the service is already gone,
        // which is exactly the state stop() wants to reach.
        guard result.exitCode == 0 || result.exitCode == 3 else {
            throw DaemonControlError.bootoutFailed(exitCode: result.exitCode)
        }
        refreshStatus()
    }

    /// Writes the canonical launch agent plist into Application Support.
    private func writeLaunchAgentPlist() throws {
        let daemonURL = Paths.daemonURL
        let spec = LaunchAgentSpec(
            label: label,
            programPath: daemonURL.path,
            standardOutPath: Paths.daemonLogURL.path,
            standardErrorPath: Paths.daemonErrorLogURL.path
        )
        let data = try spec.data()
        try FileManager.default.createDirectory(
            at: Paths.appSupportDirectory, withIntermediateDirectories: true)
        try data.write(to: Paths.launchAgentTemplateURL, options: .atomic)
    }

    private func runLaunchctl(arguments: [String]) -> (output: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return ("", -1)
        }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(decoding: data, as: UTF8.self), process.terminationStatus)
    }
}

public enum DaemonControlError: Error {
    case bootstrapFailed(exitCode: Int32)
    case bootoutFailed(exitCode: Int32)
}

/// Human-readable messages for the UI; the view shows
/// `error.localizedDescription` and stays unaware of the details.
extension DaemonControlError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .bootstrapFailed(let exitCode):
            "Could not start the daemon (launchctl exited with code \(exitCode))."
        case .bootoutFailed(let exitCode):
            "Could not stop the daemon (launchctl exited with code \(exitCode))."
        }
    }
}
