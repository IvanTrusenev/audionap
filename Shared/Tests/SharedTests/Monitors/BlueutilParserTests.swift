import Testing

@testable import Shared

struct BlueutilParserTests {

    @Test func oneMeansConnected() {
        #expect(BlueutilParser.isConnected(output: "1") == true)
    }

    @Test func zeroMeansDisconnected() {
        #expect(BlueutilParser.isConnected(output: "0") == false)
    }

    @Test func trailingNewlineIsTolerated() {
        #expect(BlueutilParser.isConnected(output: "1\n") == true)
    }

    @Test func emptyOutputIsNotConnected() {
        #expect(BlueutilParser.isConnected(output: "") == false)
    }

    @Test func garbageOutputIsNotConnected() {
        #expect(BlueutilParser.isConnected(output: "garbage") == false)
    }
}
