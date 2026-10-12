import Foundation

/// Decides when the bundled daemon must be (re)installed into Application
/// Support. Equality, not ordering: app and daemon ship in lockstep, so
/// any difference between the installed marker and the app's own version
/// means the installed copy is stale.
public enum DaemonProvisioning {
    public static func needsInstall(installedVersion: String?) -> Bool {
        installedVersion != AppIdentity.version
    }
}
