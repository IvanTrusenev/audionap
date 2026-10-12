import Testing

@testable import Shared

struct DaemonProvisioningTests {

    @Test func missingMarkerNeedsInstall() {
        #expect(DaemonProvisioning.needsInstall(installedVersion: nil))
    }

    @Test func matchingVersionIsCurrent() {
        // Compare against the shared constant, not a hardcoded literal —
        // a version bump must not break the test.
        #expect(!DaemonProvisioning.needsInstall(installedVersion: AppIdentity.version))
    }

    @Test func olderMarkerNeedsInstall() {
        #expect(DaemonProvisioning.needsInstall(installedVersion: "0.0.9"))
    }

    @Test func newerMarkerNeedsInstall() {
        #expect(DaemonProvisioning.needsInstall(installedVersion: "9.9.9"))
    }
}
