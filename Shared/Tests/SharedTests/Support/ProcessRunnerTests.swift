import Foundation
import Testing
@testable import Shared

@Suite(.serialized)
struct ProcessRunnerTests {

    /// A shell that prints to both streams and exits with a known code.
    @Test func capturesStdoutStderrAndExitCode() throws {
        let result = try #require(ProcessRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", "echo out; echo err >&2; exit 3"]
        ))
        #expect(result.stdout == "out\n")
        #expect(result.stderr == "err\n")
        #expect(result.exitCode == 3)
    }

    @Test func missingBinaryReturnsNil() {
        #expect(ProcessRunner.run(
            executable: "/nonexistent/audionap-missing",
            arguments: []
        ) == nil)
    }

    /// Regression: repeated runs must not leave descriptors behind.
    /// /dev/fd lists the process's own open fds on Darwin; the delta after
    /// 50 runs must be zero.
    @Test func repeatedRunsDoNotLeakDescriptors() throws {
        let fdCount: () throws -> Int = {
            try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
        }
        let before = try fdCount()
        for _ in 0..<50 {
            _ = ProcessRunner.run(executable: "/bin/echo", arguments: ["audionap"])
        }
        #expect(try fdCount() == before)
    }
}
