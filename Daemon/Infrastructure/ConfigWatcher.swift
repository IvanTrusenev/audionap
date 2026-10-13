import CoreFoundation
import Foundation
import Shared

/// Watches `config.plist` and reloads it on change — hot config.
///
/// A CFRunLoop timer checks the file's modification time once a
/// second. Event-driven watching proved unreliable here: the app
/// replaces the file atomically (rename), which kills a descriptor
/// watch on the old inode, and directory events do not fire for every
/// rename-replace on APFS — hand-edits via plutil showed the same
/// hole. Polling the mtime is immune to all of it, and one stat per
/// second is free. A broken file keeps the previous config — the
/// watcher never crashes the daemon.
public final class ConfigWatcher {
    private let configURL: URL
    private var timer: CFRunLoopTimer?
    private var onReload: ((AppConfig) -> Void)?
    private var lastModification: Date?

    public init(configURL: URL = Paths.configURL) {
        self.configURL = configURL
    }

    /// Starts watching; `onReload` receives the freshly loaded config.
    /// `reload()` is also called once immediately so callers start current.
    public func start(onReload: @escaping (AppConfig) -> Void) {
        guard timer == nil else { return }
        self.onReload = onReload
        var context = CFRunLoopTimerContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        let timer = CFRunLoopTimerCreate(
            nil, CFAbsoluteTimeGetCurrent() + 1, 1, 0, 0,
            { _, info in
                guard let info else { return }
                let watcher = Unmanaged<ConfigWatcher>
                    .fromOpaque(info).takeUnretainedValue()
                watcher.check()
            },
            &context)
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .defaultMode)
        self.timer = timer
        reload(onReload: onReload)
    }

    /// Loads the config once and passes it to `onReload`.
    public func reload(onReload: @escaping (AppConfig) -> Void) {
        lastModification = modificationDate()
        onReload(AppConfig.load(from: configURL))
    }

    private func check() {
        guard let onReload else { return }
        guard modificationDate() != lastModification else { return }
        reload(onReload: onReload)
    }

    private func modificationDate() -> Date? {
        guard let attributes =
            try? FileManager.default.attributesOfItem(atPath: configURL.path)
        else { return nil }
        return attributes[.modificationDate] as? Date
    }
}
