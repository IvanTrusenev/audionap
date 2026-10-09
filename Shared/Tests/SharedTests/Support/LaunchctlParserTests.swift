import Testing

@testable import Shared

struct LaunchctlParserTests {

    @Test func runningStateIsDetected() {
        #expect(LaunchctlParser.isRunning(output: "state = running\n") == true)
    }

    @Test func spawnWindowIsDetected() {
        #expect(LaunchctlParser.isRunning(output: "state = xpcproxy\n") == true)
    }

    @Test func notFoundServiceReturnsFalse() {
        #expect(
            LaunchctlParser.isRunning(
                output: """
                    Bad request.\n
                    Could not find service \"online.threealab.audionap.daemon\" in domain for user gui: 501\n 
                    """) == false)
    }

    @Test func emptyOutputReturnsFalse() {
        #expect(LaunchctlParser.isRunning(output: "") == false)
    }

    @Test func garbageOutputReturnsFalse() {
        #expect(LaunchctlParser.isRunning(output: "garbage") == false)
    }
}
