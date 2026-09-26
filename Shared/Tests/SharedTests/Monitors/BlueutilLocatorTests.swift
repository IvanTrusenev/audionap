import Foundation
import Testing

@testable import Shared

struct BlueutilLocatorTests {

    /// Creates a fresh temporary directory for this test's PATH.
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeExecutable(at path: String) throws {
        FileManager.default.createFile(atPath: path, contents: Data(), attributes: nil)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    }

    @Test func findsExecutableInPath() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let expected = dir.appendingPathComponent("blueutil").path
        try makeExecutable(at: expected)

        #expect(BlueutilLocator.resolve(in: dir.path, prefixes: []) == expected)
    }

    @Test func skipsNonExecutableFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(
            atPath: dir.appendingPathComponent("blueutil").path,
            contents: Data(), attributes: nil)

        #expect(BlueutilLocator.resolve(in: dir.path, prefixes: []) == nil)
    }

    @Test func returnsNilWhenNothingFound() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(BlueutilLocator.resolve(in: dir.path, prefixes: []) == nil)
    }

    @Test func prefixWinsOverPath() throws {
        let prefixDir = try makeTempDir()
        let pathDir = try makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: prefixDir)
            try? FileManager.default.removeItem(at: pathDir)
        }
        let expected = prefixDir.appendingPathComponent("blueutil").path
        try makeExecutable(at: expected)
        try makeExecutable(at: pathDir.appendingPathComponent("blueutil").path)

        #expect(BlueutilLocator.resolve(in: pathDir.path, prefixes: [prefixDir.path]) == expected)
    }
}
