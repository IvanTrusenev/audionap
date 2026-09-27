import AppKit
import Foundation

/// One copy of the app at a time. Every running copy registers its own
/// MenuBarExtra with SystemUIServer, so two copies mean two menu bar
/// icons. A second launch brings the first copy forward and quits.
public enum SingleInstanceGuard {

    /// Runs at launch; terminates this process if another copy of the app
    /// is already running.
    public static func enforce() {
        let isTestRun =
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let snapshots = NSWorkspace.shared.runningApplications.map {
            ProcessSnapshot(pid: $0.processIdentifier, bundleID: $0.bundleIdentifier)
        }
        guard let duplicatePID = action(
            isTestRun: isTestRun,
            ownPID: ProcessInfo.processInfo.processIdentifier,
            bundleID: Bundle.main.bundleIdentifier,
            processes: snapshots
        ) else { return }

        NSRunningApplication(processIdentifier: duplicatePID)?.activate()
        NSApp.terminate(nil)
    }

    /// The decision: the pid of the copy to activate, or nil when this
    /// launch should continue. Pure over plain data, so every branch is
    /// unit-tested; `enforce()` only wires the system boundary around it.
    static func action(
        isTestRun: Bool, ownPID: Int32, bundleID: String?, processes: [ProcessSnapshot]
    ) -> Int32? {
        // Hosted unit tests launch the real app as the test host; that is
        // not a user launch, and quitting it would kill the test run.
        if isTestRun { return nil }
        guard let bundleID else { return nil }
        return processes.first { $0.bundleID == bundleID && $0.pid != ownPID }?.pid
    }

    /// A running app reduced to the fields the guard needs.
    struct ProcessSnapshot: Equatable {
        let pid: Int32
        let bundleID: String?
    }
}
