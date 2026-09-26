import Foundation
import Shared

/// Watches `config.plist` and reloads it on change — hot config.
///
/// Watches both the file and its directory: editors rename-replace files,
/// which fires the directory event rather than the file event. Events are
/// debounced (500 ms) so one save produces one reload. A broken file keeps
/// the previous config — the watcher never crashes the daemon.
public final class ConfigWatcher {
    private let configURL: URL
    private var sources: [any DispatchSourceFileSystemObject] = []
    private var debounceWorkItem: DispatchWorkItem?

    public init(configURL: URL = Paths.configURL) {
        self.configURL = configURL
    }

    /// Starts watching; `onReload` receives the freshly loaded config.
    /// `reload()` is also called once immediately so callers start current.
    public func start(onReload: @escaping (AppConfig) -> Void) {
        for url in [configURL, configURL.deletingLastPathComponent()] {
            guard let source = makeSource(for: url) else { continue }
            source.setEventHandler { [weak self] in
                self?.scheduleReload(onReload: onReload)
            }
            source.resume()
            sources.append(source)
        }
        reload(onReload: onReload)
    }

    /// Loads the config once and passes it to `onReload`.
    public func reload(onReload: @escaping (AppConfig) -> Void) {
        onReload(AppConfig.load(from: configURL))
    }

    private func makeSource(for url: URL) -> DispatchSourceFileSystemObject? {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        return DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write, queue: .main)
    }

    private func scheduleReload(onReload: @escaping (AppConfig) -> Void) {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.reload(onReload: onReload)
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
}
