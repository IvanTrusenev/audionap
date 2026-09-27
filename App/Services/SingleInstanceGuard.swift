import AppKit
import Foundation

/// One copy of the app at a time. Every running copy registers its own
/// MenuBarExtra with SystemUIServer, so two copies mean two menu bar
/// icons. A second launch brings the first copy forward and quits.
public enum SingleInstanceGuard {

    /// Runs at launch; terminates this process if another copy of the app
    /// is already running.
    public static func enforce() {
        // Hosted unit tests and Xcode previews launch the real app as
        // their host process; those are not user launches, and quitting
        // them would kill the test run or the preview.
        let isHostedLaunch =
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        let snapshots = NSWorkspace.shared.runningApplications.map {
            ProcessSnapshot(pid: $0.processIdentifier, bundleID: $0.bundleIdentifier)
        }
        
        guard let duplicatePID = action(
            isHostedLaunch: isHostedLaunch,
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
        isHostedLaunch: Bool, ownPID: Int32, bundleID: String?, processes: [ProcessSnapshot]
    ) -> Int32? {
        if isHostedLaunch { return nil }
        guard let bundleID else { return nil }
        return processes.first { $0.bundleID == bundleID && $0.pid != ownPID }?.pid
    }

    /// A running app reduced to the fields the guard needs.
    struct ProcessSnapshot: Equatable {
        let pid: Int32
        let bundleID: String?
    }
}
