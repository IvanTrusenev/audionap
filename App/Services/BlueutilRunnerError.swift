import Foundation

public enum BlueutilRunnerError: Error, Sendable {
    case notFound
    case connectFailed(exitCode: Int32)
    case disconnectFailed(exitCode: Int32)
}

/// Human-readable messages for the UI; the view shows
/// `error.localizedDescription` and stays unaware of the details.
extension BlueutilRunnerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notFound:
            String(localized: "error.blueutilNotFound")
        case .connectFailed(let exitCode):
            // Int64, not Int — see the same note in DaemonControlError.
            String(localized: "error.connectFailed \(Int64(exitCode))")
        case .disconnectFailed(let exitCode):
            String(localized: "error.disconnectFailed \(Int64(exitCode))")
        }
    }
}
