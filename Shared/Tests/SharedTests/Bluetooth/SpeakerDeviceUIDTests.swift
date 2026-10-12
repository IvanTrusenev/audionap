import Testing

@testable import Shared

struct SpeakerDeviceUIDTests {

    @Test func outputSideParses() throws {
        let device = try #require(
            SpeakerDeviceUID.parse("AC-EF-92-D8-A6-7B:output"))
        #expect(device.mac == "ac-ef-92-d8-a6-7b")
        #expect(device.side == .output)
    }

    @Test func inputSideParses() throws {
        let device = try #require(
            SpeakerDeviceUID.parse("AC-EF-92-D8-A6-7B:input"))
        #expect(device.mac == "ac-ef-92-d8-a6-7b")
        #expect(device.side == .input)
    }

    @Test func colonFormMACNormalizes() throws {
        let device = try #require(
            SpeakerDeviceUID.parse("AC:EF:92:D8:A6:7B:output"))
        #expect(device.mac == "ac-ef-92-d8-a6-7b")
        #expect(device.side == .output)
    }

    @Test func anotherDeviceCarriesItsOwnMAC() throws {
        let device = try #require(
            SpeakerDeviceUID.parse("11-22-33-44-55-66:output"))
        #expect(device.mac == "11-22-33-44-55-66")
    }

    @Test func unknownSideReturnsNil() {
        #expect(SpeakerDeviceUID.parse("AC-EF-92-D8-A6-7B:mic") == nil)
    }

    @Test func invalidMACPartReturnsNil() {
        #expect(SpeakerDeviceUID.parse("AC-EF-92-D8-A6:output") == nil)
    }

    @Test func garbageReturnsNil() {
        #expect(SpeakerDeviceUID.parse("not-a-uid") == nil)
    }
}
