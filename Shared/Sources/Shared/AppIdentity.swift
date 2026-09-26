import Foundation

/// Product identity shared by the app and the daemon.
/// Matches `PRODUCT_BUNDLE_IDENTIFIER` in the Xcode project.
///
/// Scope: answers "who we are" — bundle ID, display name, version.
/// Locations ("where we are") live in `Paths`, not here. If something
/// non-identity wants in, it's a signal for a new focused enum.
/// A caseless enum is the Swift idiom for grouping related constants
/// without instances.
public enum AppIdentity {
    public static let bundleID = "online.threealab.audionap"
}
