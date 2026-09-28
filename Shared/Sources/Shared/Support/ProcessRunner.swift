import Foundation

/// Runs an executable capturing stdout and stderr separately, closing the
/// pipe descriptors explicitly.
///
/// Explicit closing matters twice: the parent's write ends must close so
/// `readDataToEndOfFile` sees EOF, and every end must close because
/// descriptor lifetime must not depend on Pipe/FileHandle deallocation.
/// Only for tools with small outputs — a child writing more than the pipe
/// buffer while the parent is in `waitUntilExit` would deadlock.
public enum ProcessRunner {

    public struct Result: Equatable {
        public let stdout: String
        public let stderr: String
        public let exitCode: Int32

        public init(stdout: String, stderr: String, exitCode: Int32) {
            self.stdout = stdout
            self.stderr = stderr
            self.exitCode = exitCode
        }
    }

    /// Runs `executable` with `arguments`; nil when the process cannot be
    /// launched (missing binary, spawn failure).
    public static func run(executable: String, arguments: [String]) -> Result? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return nil
        }

        // Close the parent's write ends: guarantees EOF for the reads below
        // and leaves no descriptor behind whatever Foundation retains.
        try? stdoutPipe.fileHandleForWriting.close()
        try? stderrPipe.fileHandleForWriting.close()

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        try? stdoutPipe.fileHandleForReading.close()
        try? stderrPipe.fileHandleForReading.close()

        return Result(
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }
}
