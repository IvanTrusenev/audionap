import Foundation

/// Result of config normalization: the fixed copy plus a list of what was
/// fixed (for the log). A named type instead of a tuple — the public API of
/// the core should not depend on throwaway constructs.
public struct NormalizedConfig: Equatable, Sendable {
    public let config: AppConfig
    public let warnings: [String]
}
