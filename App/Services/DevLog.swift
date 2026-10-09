import Foundation
import Shared
import os

/// Debug-tracing signature for one debugging session. When non-empty,
/// every `DevLog.log` call writes under this value as the unified-log
/// *category*, with the point name in the message body — one predicate
/// collects the whole session:
///
///     log stream --predicate 'subsystem == "online.threealab.audionap"
///         AND category == "<signature>"' --style compact
///
/// When empty, each call logs under its own point name as the category.
///
/// Version the signature per fix iteration (`settleRace_v1`, `_v2`, …)
/// so old and new logs can never mix — grep by the base prefix when the
/// command must not change between iterations. Reset to `""` when the
/// debugging is done.
public nonisolated(unsafe) var devLogSignature = ""

/// The ready-made debug-tracing tool: a point name plus a message,
/// compiled away in release builds.
public enum DevLog {
    private static let subsystem = AppIdentity.bundleID

    /// Logs a debug-tracing point. `name` is the point (e.g. `"tap"`,
    /// `"settle"`), `message` the body. Uses `.notice` — the level that
    /// `log show`/`log stream` display and persist by default.
    ///
    ///     DevLog.log("tap", "stop (status \(status))")
    public static func log(_ name: String, _ message: String) {
        #if DEBUG
        let category = devLogSignature.isEmpty ? name : devLogSignature
        let body = devLogSignature.isEmpty ? message : "[\(name)] \(message)"
        Logger(subsystem: subsystem, category: category)
            .notice("\(body, privacy: .public)")
        #endif
    }
}
