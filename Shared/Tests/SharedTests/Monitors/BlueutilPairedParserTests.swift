import Testing

@testable import Shared

struct BlueutilPairedParserTests {

    @Test func parsesPairedOutput() {
        let output = """
            address: 00-76-25-22-04-db, not connected, not favourite, paired, name: "Vault", recent access date: 2026-09-27 17:17:10 +0000
            address: 08-eb-ed-ab-41-9b, connected (master, -37 dBm), not favourite, paired, name: "Mi Speaker", recent access date: 2026-09-27 17:17:10 +0000
            """

        let devices = BlueutilPairedParser.parse(output: output)

        #expect(
            devices == [
                BlueutilDevice(address: "00-76-25-22-04-db", name: "Vault", connected: false),
                BlueutilDevice(address: "08-eb-ed-ab-41-9b", name: "Mi Speaker", connected: true),
            ])
    }

    @Test func emptyOutputYieldsNoDevices() {
        #expect(BlueutilPairedParser.parse(output: "") == [])
    }

    @Test func malformedLinesAreSkipped() {
        let output = """
            address: 08-eb-ed-ab-41-9b, not connected, not favourite, paired, name: "Mi Speaker", recent access date: 2026-09-27 17:17:10 +0000
            some garbage line without address
            address: no-mac-here, paired, name: "Broken"
            """

        let devices = BlueutilPairedParser.parse(output: output)

        #expect(devices.count == 1)
        #expect(devices[0].name == "Mi Speaker")
    }

    @Test func emptyNameIsParsed() {
        let output = #"address: aa-bb-cc-dd-ee-ff, paired, name: "", recent access date: x"#

        let devices = BlueutilPairedParser.parse(output: output)

        #expect(
            devices == [
                BlueutilDevice(address: "aa-bb-cc-dd-ee-ff", name: "", connected: false)
            ])
    }
}
