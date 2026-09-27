import Testing

@testable import Shared

struct BluetoothMACTests {

    @Test func dashFormIsCanonical() {
        #expect(BluetoothMAC.normalize("aa-bb-cc-dd-ee-ff") == "aa-bb-cc-dd-ee-ff")
    }

    @Test func colonFormIsNormalized() {
        #expect(BluetoothMAC.normalize("AA:BB:CC:DD:EE:FF") == "aa-bb-cc-dd-ee-ff")
    }

    @Test func compactFormIsNormalized() {
        #expect(BluetoothMAC.normalize("aabbccddeeff") == "aa-bb-cc-dd-ee-ff")
    }

    @Test func wrongLengthIsRejected() {
        #expect(BluetoothMAC.normalize("aa-bb-cc") == nil)
        #expect(BluetoothMAC.normalize("aa-bb-cc-dd-ee-ff-00") == nil)
    }

    @Test func nonHexIsRejected() {
        #expect(BluetoothMAC.normalize("zz-bb-cc-dd-ee-ff") == nil)
    }

    @Test func spacesAreRejected() {
        #expect(BluetoothMAC.normalize("aa bb cc dd ee ff") == nil)
    }
}
