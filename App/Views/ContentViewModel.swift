import Foundation
import Observation
import Shared

/// The menu bar window's presentation model: owns the daemon
/// controller, the live-state reader and the installer, and exposes
/// the values the widgets bind or display. The view only arranges
/// the widgets.
@MainActor
@Observable
public final class ContentViewModel {
    /// The daemon's launchd controller — passed to ControlRow, which
    /// drives Start/Stop.
    public let controller: DaemonController

    /// The config store — the thresholds' fresher truth than the
    /// daemon's publication round-trip.
    private let store: ConfigStore
    /// Provisions the bundled daemon on first window open.
    private let installer = DaemonInstaller()
    /// Reads the daemon's live state from state.plist on a timer.
    private let stateReader = StateReader()

    /// Install failures surface in an alert (same pattern as
    /// ControlRow).
    public var installErrorMessage = ""
    public var showingInstallError = false

    public init(store: ConfigStore) {
        self.store = store
        self.controller = DaemonController()
    }

    // Live state, proxied from the reader.

    public var daemonAlive: Bool { stateReader.daemonAlive }
    public var bands: [Double] { stateReader.bands }
    public var playing: Bool { stateReader.playing }
    public var quietSeconds: Int { stateReader.quietSeconds }
    public var idleSeconds: Int { stateReader.idleSeconds }

    // Thresholds are config, not runtime state: the store is their
    // fresher truth than the daemon's publication round-trip.

    public var silenceTimeoutSeconds: Int { store.silenceTimeoutSeconds }
    public var inputWindowSeconds: Int { store.inputWindowSeconds }
    public var ignoreUserActivity: Bool { store.ignoreUserActivity }

    /// The window's onAppear: refresh the daemon status and start the
    /// live-state reader.
    public func start() {
        controller.refreshStatus()
        stateReader.start()
    }

    /// The window's onDisappear: stop the live-state reader.
    public func stop() {
        stateReader.stop()
    }

    /// Provisions the bundled daemon on first window open.
    public func ensureDaemonInstalled() async {
        // Preview hosts run the whole app (same bundle ID) and unit
        // tests host it too — neither should install the daemon.
        let environment = ProcessInfo.processInfo.environment
        guard environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1",
              environment["XCTestConfigurationFilePath"] == nil else {
            return
        }
        do {
            _ = try await installer.ensureInstalled()
        } catch {
            installErrorMessage = error.localizedDescription
            showingInstallError = true
        }
    }
}
