import Testing

@testable import AudioNap

struct SingleInstanceGuardTests {

    private let bundleID = "online.threealab.audionap"

    @Test func duplicateInstanceIsDetected() {
        let processes = [
            SingleInstanceGuard.ProcessSnapshot(pid: 100, bundleID: bundleID),
            SingleInstanceGuard.ProcessSnapshot(pid: 200, bundleID: bundleID),
        ]
        #expect(
            SingleInstanceGuard.action(
                isHostedLaunch: false, ownPID: 100, bundleID: bundleID, processes: processes
            ) == 200
        )
    }

    @Test func ownInstanceIsIgnored() {
        let processes = [
            SingleInstanceGuard.ProcessSnapshot(pid: 100, bundleID: bundleID),
        ]
        #expect(
            SingleInstanceGuard.action(
                isHostedLaunch: false, ownPID: 100, bundleID: bundleID, processes: processes
            ) == nil
        )
    }

    @Test func foreignAppsAreIgnored() {
        let processes = [
            SingleInstanceGuard.ProcessSnapshot(pid: 300, bundleID: "com.apple.finder"),
        ]
        #expect(
            SingleInstanceGuard.action(
                isHostedLaunch: false, ownPID: 100, bundleID: bundleID, processes: processes
            ) == nil
        )
    }

    @Test func nilBundleIDsAreIgnored() {
        let processes = [
            SingleInstanceGuard.ProcessSnapshot(pid: 400, bundleID: nil),
        ]
        #expect(
            SingleInstanceGuard.action(
                isHostedLaunch: false, ownPID: 100, bundleID: bundleID, processes: processes
            ) == nil
        )
    }

    @Test func testRunAlwaysContinues() {
        // The hosted test process is a real launch of the app — the guard
        // must stand down even when a duplicate exists.
        let processes = [
            SingleInstanceGuard.ProcessSnapshot(pid: 100, bundleID: bundleID),
            SingleInstanceGuard.ProcessSnapshot(pid: 200, bundleID: bundleID),
        ]
        #expect(
            SingleInstanceGuard.action(
                isHostedLaunch: true, ownPID: 100, bundleID: bundleID, processes: processes
            ) == nil
        )
    }

    @Test func missingBundleIDContinues() {
        #expect(
            SingleInstanceGuard.action(
                isHostedLaunch: false, ownPID: 100, bundleID: nil, processes: []
            ) == nil
        )
    }
}
