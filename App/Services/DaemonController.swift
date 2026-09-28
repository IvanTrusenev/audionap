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
    public private(set) var status: DaemonStatus = .stopped

    /// launchd label: online.threealab.audionap.daemon (matches the plist file name).
    nonisolated private static let label = "\(AppIdentity.bundleID).daemon"
    /// launchd domain: gui/<uid> — the user's login session.
    nonisolated private static var domain: String { "gui/\(getuid())" }

    public init() {}
    
    /// Creates a controller already in the given state — for previews,
    /// which can't run real launchctl operations.
    public init(status: DaemonStatus) {
        self.status = status
    }

    /// Queries launchd and updates `status`. No-op while an operation is
    /// in flight — a stale reading must not clobber `transitioning`.
    public func refreshStatus() {
        guard !status.isTransitioning else { return }
        settle()
    }

    /// Start: write the canonical plist, then (re)bootstrap the agent.
    /// bootout first is required — bootstrap fails with exit code 5 while
    /// a previous instance of the service is still in the domain. The
    /// blocking launchctl sequence runs off the main actor, so the UI
    /// stays responsive and shows `transitioning` meanwhile.
    public func start() async throws {
        status = DaemonStatus.next(from: status, event: .operationStarted)
        do {
            try await Task.detached(priority: .userInitiated) {
                try Self.startBlocking()
            }.value
        } catch {
            settle()
            throw error
        }
        settle()
    }

    /// Stop: bootout the agent.
    public func stop() async throws {
        status = DaemonStatus.next(from: status, event: .operationStarted)
        do {
            try await Task.detached(priority: .userInitiated) {
                let result = Self.runLaunchctl(
                    arguments: ["bootout", "\(Self.domain)/\(Self.label)"])
                // exit code 3 = "No such process": the service is already
                // gone, which is exactly the state stop() wants to reach.
                guard result.exitCode == 0 || result.exitCode == 3 else {
                    throw DaemonControlError.bootoutFailed(exitCode: result.exitCode)
                }
            }.value
        } catch {
            settle()
            throw error
        }
        settle()
    }

    /// Overwrites `status` from a fresh launchctl reading (unlike
    /// `refreshStatus`, which refuses during a transition).
    private func settle() {
        let result = Self.runLaunchctl(
            arguments: ["print", "\(Self.domain)/\(Self.label)"])
        status = DaemonStatus.next(
            from: status,
            event: .operationSettled(
                running: LaunchctlParser.isRunning(output: result.output)))
    }

    /// The blocking part of `start()`, safe to run off the main actor.
    nonisolated private static func startBlocking() throws {
        try writeLaunchAgentPlist()

        _ = runLaunchctl(arguments: ["bootout", "\(domain)/\(label)"])
        let exitCode = bootstrapWithRetry()
        if exitCode != 0 {
            // A retry can land on the far side of the race: bootstrap may
            // have failed while the job actually loaded. Trust launchd.
            let output = runLaunchctl(arguments: ["print", "\(domain)/\(label)"]).output
            if !LaunchctlParser.isRunning(output: output) {
                throw DaemonControlError.bootstrapFailed(exitCode: exitCode)
            }
        }
    }

    /// bootout removes the service from the domain asynchronously, so a
    /// bootstrap issued right after can hit the half-removed record and
    /// fail with exit code 5. Retry until `deadline` — launchd's exit
    /// timeout (5s for this job) bounds the teardown — and report the
    /// last exit code.
    nonisolated private static func bootstrapWithRetry() -> Int32 {
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

    /// Writes the canonical launch agent plist into Application Support.
    nonisolated private static func writeLaunchAgentPlist() throws {
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

    nonisolated private static func runLaunchctl(arguments: [String]) -> (output: String, exitCode: Int32) {
        guard let result = ProcessRunner.run(executable: "/bin/launchctl", arguments: arguments) else {
            return ("", -1)
        }
        return (result.stdout + result.stderr, result.exitCode)
    }
}

public enum DaemonControlError: Error, Sendable {
    case bootstrapFailed(exitCode: Int32)
    case bootoutFailed(exitCode: Int32)
}

/// Human-readable messages for the UI; the view shows
/// `error.localizedDescription` and stays unaware of the details.
extension DaemonControlError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .bootstrapFailed(let exitCode):
            // Int64, not Int: the runtime lookup key for an interpolated
            // integer is "%lld", and so is the extractor's key for Int64 —
            // with plain Int Xcode's extractor derives "%d" and the catalog
            // gains a junk key that never resolves.
            String(localized: "error.bootstrapFailed \(Int64(exitCode))")
        case .bootoutFailed(let exitCode):
            String(localized: "error.bootoutFailed \(Int64(exitCode))")
        }
    }
}
