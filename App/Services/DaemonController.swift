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
    /// Mirrors StateReader.staleAfter: the heartbeat reads "alive" for
    /// up to this long after the daemon actually died.
    public static let heartbeatFreshness: TimeInterval = 1.5

    public private(set) var status: DaemonStatus = .stopped
    /// When the last settle happened — a confirmed stop outruns the
    /// heartbeat's freshness window, and the UI uses this to trust
    /// the settled truth over the stale "alive" reading.
    public private(set) var lastSettleDate = Date.distantPast

    /// launchd label: online.threealab.audionap.daemon (matches the plist file name).
    nonisolated static let label = "\(AppIdentity.bundleID).daemon"
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

    /// Syncs the settled state with the heartbeat before an operation —
    /// an external stop/start leaves the local machine stale, and the
    /// next transition must start from the truth, not from memory.
    /// No-op while an operation is in flight, and no-op right after a
    /// settle: the settled launchd truth outruns the heartbeat by its
    /// freshness window, and a stale heartbeat must not overwrite it
    /// (a Start clicked right after Stop would otherwise read as Stop).
    public func adopt(alive: Bool) {
        guard !status.isTransitioning else { return }
        guard Date().timeIntervalSince(lastSettleDate) >= Self.heartbeatFreshness else {
            return
        }
        if alive, status == .stopped {
            status = .running
        }
        if !alive, status == .running {
            status = .stopped
        }
    }

    /// Whether the agent is currently running, per launchd.
    nonisolated static func isAgentRunning() -> Bool {
        let result = runLaunchctl(arguments: ["print", "\(domain)/\(label)"])
        return LaunchctlParser.isRunning(output: result.output)
    }
    
    /// Start: write the canonical plist, then (re)bootstrap the agent.
    /// bootout first is required — bootstrap fails with exit code 5 while
    /// a previous instance of the service is still in the domain. The
    /// blocking launchctl sequence runs off the main actor, so the UI
    /// stays responsive and shows `transitioning` meanwhile.
    public func start() async throws {
        // Double-click protection: the UI's disabled state propagates
        // asynchronously, so only this synchronous guard can stop a
        // second click from racing its own bootout/bootstrap cycle.
        guard !status.isTransitioning else {
            return
        }
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

    /// Stop: bootout the agent, then wait until launchd confirms the
    /// job is gone — bootout tears down asynchronously, and a settle
    /// right after it could read the half-dead job as still running
    /// and flip the button back. The wait mirrors bootstrapWithRetry:
    /// poll per attempt until the state is confirmed or the deadline
    /// passes, then settle once.
    public func stop() async throws {
        // Same double-click protection as start().
        guard !status.isTransitioning else {
            return
        }
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
            try await Task.detached(priority: .userInitiated) {
                Self.waitUntilStopped(deadline: 7)
            }.value
        } catch {
            settle()
            throw error
        }
        settle()
    }

    /// Polls launchd until the job is gone or the deadline passes —
    /// stop()'s counterpart of bootstrapWithRetry's trust-per-attempt.
    nonisolated private static func waitUntilStopped(deadline: TimeInterval) {
        let deadlineDate = Date().addingTimeInterval(deadline)
        while Date() < deadlineDate {
            if !isAgentRunning() { return }
            Thread.sleep(forTimeInterval: 0.25)
        }
    }

    /// Overwrites `status` from a fresh launchctl reading (unlike
    /// `refreshStatus`, which refuses during a transition).
    private func settle() {
        let result = Self.runLaunchctl(
            arguments: ["print", "\(Self.domain)/\(Self.label)"])
        let running = LaunchctlParser.isRunning(output: result.output)
        lastSettleDate = Date()
        status = DaemonStatus.next(
            from: status,
            event: .operationSettled(running: running))
    }

    /// The blocking part of `start()`, safe to run off the main actor.
    nonisolated private static func startBlocking() throws {
        // Idempotent start: a second click lands while the first
        // bootstrap just finished — the heartbeat still reads dead, so
        // the toggle rightfully offers Start again, but the job is
        // already running. A bootout here would kill the healthy
        // daemon, and the retry would report a false success on the
        // dying job.
        if isAgentRunning() {
            return
        }
        try writeLaunchAgentPlist()

        _ = runLaunchctl(arguments: ["bootout", "\(domain)/\(label)"])
        let exitCode = bootstrapWithRetry()
        if exitCode != 0 {
            throw DaemonControlError.bootstrapFailed(exitCode: exitCode)
        }
    }

    /// bootout removes the service from the domain asynchronously, so a
    /// bootstrap issued right after can hit the half-removed record and
    /// fail with exit code 5. Retry until `deadline` — launchd's exit
    /// timeout (5s for this job) bounds the teardown, plus margin — and
    /// report the last exit code. A retry can land on the far side of
    /// the race (bootstrap failed, but the job actually loaded), so a
    /// failed attempt also checks whether the job is running regardless:
    /// trust launchd per attempt, not just at the end.
    nonisolated private static func bootstrapWithRetry() -> Int32 {
        let deadline = Date().addingTimeInterval(7)
        var exitCode: Int32 = -1
        repeat {
            exitCode = runLaunchctl(arguments: [
                "bootstrap", domain, Paths.launchAgentTemplateURL.path,
            ]).exitCode
            if exitCode == 0 {
                return 0
            }
            let output = runLaunchctl(arguments: ["print", "\(domain)/\(label)"]).output
            if LaunchctlParser.isRunning(output: output) {
                return 0
            }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return exitCode
    }

    /// Writes the canonical launch agent plist into Application Support.
    /// Also used by `AutostartController` to refresh the canonical copy
    /// before installing the LaunchAgents one.
    nonisolated static func writeLaunchAgentPlist() throws {
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

    nonisolated static func runLaunchctl(arguments: [String]) -> (output: String, exitCode: Int32) {
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
            String(format: LanguageStore.shared.string("error.bootstrapFailed %lld"), Int64(exitCode))
        case .bootoutFailed(let exitCode):
            String(format: LanguageStore.shared.string("error.bootoutFailed %lld"), Int64(exitCode))
        }
    }
}
