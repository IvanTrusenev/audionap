import Foundation
import Testing

@testable import Shared

struct LogTailParserTests {

    @Test func returnsLastLines() {
        let data = Data("one\ntwo\nthree\nfour\n".utf8)
        #expect(LogTailParser.lastLines(in: data, limit: 2) == ["three", "four"])
    }

    @Test func trailingNewlineDoesNotCreateEmptyLine() {
        let data = Data("one\ntwo\n".utf8)
        #expect(LogTailParser.lastLines(in: data, limit: 5) == ["one", "two"])
    }

    @Test func limitLargerThanContentReturnsAllLines() {
        let data = Data("one\ntwo\n".utf8)
        #expect(LogTailParser.lastLines(in: data, limit: 10) == ["one", "two"])
    }

    @Test func emptyDataReturnsEmpty() {
        #expect(LogTailParser.lastLines(in: Data(), limit: 5) == [])
    }

    @Test func zeroLimitReturnsEmpty() {
        #expect(LogTailParser.lastLines(in: Data("one\ntwo\n".utf8), limit: 0) == [])
    }

    @Test func emptyMiddleLinesAreKept() {
        let data = Data("one\n\ntwo\n".utf8)
        #expect(LogTailParser.lastLines(in: data, limit: 5) == ["one", "", "two"])
    }
}
