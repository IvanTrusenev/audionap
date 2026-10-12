import Testing

@testable import Shared

struct SpeakerDeviceUIDTests {

    @Test func speakerOutputMatches() {
        #expect(
            SpeakerDeviceUID.isSpeakerOutput(
                uid: "AC-EF-92-D8-A6-7B:output",
                mac: "ac-ef-92-d8-a6-7b"))
    }

    @Test func speakerInputIsNotTheOutput() {
        #expect(
            !SpeakerDeviceUID.isSpeakerOutput(
                uid: "AC-EF-92-D8-A6-7B:input",
                mac: "ac-ef-92-d8-a6-7b"))
    }

    @Test func anotherDeviceDoesNotMatch() {
        #expect(
            !SpeakerDeviceUID.isSpeakerOutput(
                uid: "11-22-33-44-55-66:output",
                mac: "ac-ef-92-d8-a6-7b"))
    }

    @Test func colonFormMACMatches() {
        #expect(
            SpeakerDeviceUID.isSpeakerOutput(
                uid: "AC:EF:92:D8:A6:7B:output",
                mac: "ac:ef:92:d8:a6:7b"))
    }

    @Test func garbageMACReturnsFalse() {
        #expect(
            !SpeakerDeviceUID.isSpeakerOutput(
                uid: "AC-EF-92-D8-A6-7B:output",
                mac: "not-a-mac"))
    }
}
