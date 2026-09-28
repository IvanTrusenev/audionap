import Testing

@testable import Shared

struct DaemonProvisioningTests {

    @Test func missingMarkerNeedsInstall() {
        #expect(DaemonProvisioning.needsInstall(installedVersion: nil))
    }

    @Test func matchingVersionIsCurrent() {
        #expect(!DaemonProvisioning.needsInstall(installedVersion: "0.1.0"))
    }

    @Test func olderMarkerNeedsInstall() {
        #expect(DaemonProvisioning.needsInstall(installedVersion: "0.0.9"))
    }

    @Test func newerMarkerNeedsInstall() {
        #expect(DaemonProvisioning.needsInstall(installedVersion: "9.9.9"))
    }
}
