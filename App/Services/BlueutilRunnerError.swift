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
            LanguageStore.shared.string("error.blueutilNotFound")
        case .connectFailed(let exitCode):
            // Int64, not Int — see the same note in DaemonControlError.
            String(format: LanguageStore.shared.string("error.connectFailed %lld"), Int64(exitCode))
        case .disconnectFailed(let exitCode):
            String(format: LanguageStore.shared.string("error.disconnectFailed %lld"), Int64(exitCode))
        }
    }
}
