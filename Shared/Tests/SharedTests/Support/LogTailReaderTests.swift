import Foundation
import Testing

@testable import Shared

struct LogTailReaderTests {

    private func temporaryFile(content: Data) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tail-\(UUID().uuidString).log")
        try! content.write(to: url)
        return url
    }

    @Test func smallFileReadsFullyUntruncated() throws {
        let url = temporaryFile(content: Data("one\ntwo\n".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        let tail = try #require(LogTailReader.readTail(from: url, byteLimit: 100))
        #expect(tail.data == Data("one\ntwo\n".utf8))
        #expect(tail.truncated == false)
    }

    @Test func bigFileReadsAtMostTheLimitAndReportsTruncation() throws {
        var content = Data(repeating: 0x61, count: 5_000)  // 'a' x 5000
        content.append(Data("\nend-marker\n".utf8))
        let url = temporaryFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let tail = try #require(LogTailReader.readTail(from: url, byteLimit: 1_000))
        #expect(tail.data.count <= 1_000)
        #expect(tail.truncated)
        // The tail ends at the very end of the file.
        #expect(tail.data.suffix(11) == Data("end-marker\n".utf8))
    }

    @Test func missingFileReturnsNil() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).log")
        #expect(LogTailReader.readTail(from: url, byteLimit: 100) == nil)
    }
}
