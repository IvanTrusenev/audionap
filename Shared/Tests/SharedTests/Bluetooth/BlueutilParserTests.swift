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

    @Test func parsesPairedOutput() {
        let output = """
            address: 00-76-25-22-04-db, not connected, not favourite, paired, name: "Vault", recent access date: 2026-09-27 17:17:10 +0000
            address: 08-eb-ed-ab-41-9b, connected (master, -37 dBm), not favourite, paired, name: "Mi Speaker", recent access date: 2026-09-27 17:17:10 +0000
            """

        let devices = BlueutilParser.pairedDevices(output: output)

        #expect(
            devices == [
                BlueutilDevice(address: BluetoothMAC("00-76-25-22-04-db")!, name: "Vault", connected: false),
                BlueutilDevice(address: BluetoothMAC("08-eb-ed-ab-41-9b")!, name: "Mi Speaker", connected: true),
            ])
    }

    @Test func emptyPairedOutputYieldsNoDevices() {
        #expect(BlueutilParser.pairedDevices(output: "") == [])
    }

    @Test func malformedPairedLinesAreSkipped() {
        let output = """
            address: 08-eb-ed-ab-41-9b, not connected, not favourite, paired, name: "Mi Speaker", recent access date: 2026-09-27 17:17:10 +0000
            some garbage line without address
            address: no-mac-here, paired, name: "Broken"
            """

        let devices = BlueutilParser.pairedDevices(output: output)

        #expect(devices.count == 1)
        #expect(devices[0].name == "Mi Speaker")
    }

    @Test func emptyNameIsParsed() {
        let output = #"address: aa-bb-cc-dd-ee-ff, paired, name: "", recent access date: x"#

        let devices = BlueutilParser.pairedDevices(output: output)

        #expect(
            devices == [
                BlueutilDevice(address: BluetoothMAC("aa-bb-cc-dd-ee-ff")!, name: "", connected: false)
            ])
    }
}
