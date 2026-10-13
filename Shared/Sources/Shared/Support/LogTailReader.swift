import Foundation

/// Reads the last `byteLimit` bytes of a file backwards in chunks —
/// shared by the app's log window and the daemon's log rotation, so a
/// log that grows forever never loads fully. Returns the tail plus
/// whether earlier bytes exist; nil when the file cannot be read.
public enum LogTailReader {
    public static func readTail(
        from url: URL, byteLimit: Int
    ) -> (data: Data, truncated: Bool)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let chunkSize = 8_192
        var offset = (try? handle.seekToEnd()) ?? 0
        var collected = Data()

        while true {
            let readStart = offset >= chunkSize ? offset - UInt64(chunkSize) : 0
            try? handle.seek(toOffset: readStart)
            let chunk = handle.readDataToEndOfFile()
            collected = chunk + collected
            guard collected.count >= byteLimit || readStart == 0 else {
                offset = readStart
                continue
            }
            // Truncated means "bytes exist before the tail": either we
            // stopped before the file's start, or a single chunk read
            // the whole file and it still exceeds the limit.
            return (
                Data(collected.suffix(byteLimit)),
                readStart > 0 || collected.count > byteLimit
            )
        }
    }
}
