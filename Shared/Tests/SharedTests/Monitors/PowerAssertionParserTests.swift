import Testing

@testable import Shared

struct PowerAssertionParserTests {

    @Test func playingAudioAssertionIsDetected() {
        #expect(
            PowerAssertionParser.isPlayingAudio(
                in: """
                    pid 123(yandex.music): [0x0000001f00012345] 00:01:23 NoIdleSleepAssertion named: "Playing audio"
                    """
            ) == true)
    }

    @Test func unrelatedAssertionsReturnFalse() {
        #expect(
            PowerAssertionParser.isPlayingAudio(
                in: """
                    pid 123(finder): [0x0000001f00012345] 00:01:23 UserIsActive named: "com.apple.iohideventsystem.queue.tickle service"
                    """) == false)
    }

    @Test func emptyOutputReturnsFalse() {
        #expect(PowerAssertionParser.isPlayingAudio(in: "") == false)
    }
}
