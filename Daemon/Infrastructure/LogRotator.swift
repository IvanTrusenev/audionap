import CoreFoundation
import Foundation
import Shared

/// Keeps the daemon's logs bounded. When a file passes 1 MB it is
/// truncated in place to its last 256 KB with a marker line — in
/// place, because replacing the file would break launchd's redirect
/// (launchd keeps writing to the old inode). Checked once at start
/// and then hourly; the same rule applies to the error log.
public final class LogRotator {
    private static let threshold = 1_000_000
    private static let tailSize = 256_000
    private static let interval: TimeInterval = 3_600

    private let files: [URL]
    private var timer: CFRunLoopTimer?

    public init(files: [URL] = [Paths.daemonLogURL, Paths.daemonErrorLogURL]) {
        self.files = files
    }

    /// Installs the hourly timer and checks once immediately.
    public func start() {
        guard timer == nil else { return }
        rotateAll()
        var context = CFRunLoopTimerContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        let timer = CFRunLoopTimerCreate(
            nil, CFAbsoluteTimeGetCurrent() + Self.interval, Self.interval, 0, 0,
            { _, info in
                guard let info else { return }
                Unmanaged<LogRotator>
                    .fromOpaque(info).takeUnretainedValue().rotateAll()
            },
            &context)
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .defaultMode)
        self.timer = timer
    }

    public func rotateAll() {
        for url in files {
            Self.rotateIfNeeded(at: url)
        }
    }

    private static func rotateIfNeeded(at url: URL) {
        guard let attributes =
            try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? Int,
            size > threshold,
            let tail = LogTailReader.readTail(from: url, byteLimit: tailSize),
            let handle = try? FileHandle(forWritingTo: url) else {
            return
        }
        defer { try? handle.close() }

        var replacement = Data("… log truncated\n".utf8)
        replacement.append(LogTailParser.lineAligned(tail.data))
        do {
            try handle.truncate(atOffset: 0)
            try handle.write(contentsOf: replacement)
            // The event line lands after the tail (O_APPEND), giving
            // the truncation a timestamp — the marker itself has none.
            DaemonLog.print(
                .ok,
                "log rotated: \(url.lastPathComponent) \(Self.megabytes(size)) → 256 KB"
            )
        } catch {
            // Rotation is best-effort — a failed trim must not kill
            // the daemon over a log file.
            DaemonLog.print(
                .warn, "log rotation failed for \(url.lastPathComponent): \(error)")
        }
    }

    /// "1.7 MB" with one decimal — a human size for the log line.
    private static func megabytes(_ bytes: Int) -> String {
        String(format: "%.1f MB", Double(bytes) / 1_000_000)
    }
}
