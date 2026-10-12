import Foundation
import Testing

@testable import Shared

struct BluetoothMACTests {

    @Test func dashFormIsCanonical() {
        #expect(BluetoothMAC("aa-bb-cc-dd-ee-ff")?.value == "aa-bb-cc-dd-ee-ff")
    }

    @Test func colonFormIsNormalized() {
        #expect(BluetoothMAC("AA:BB:CC:DD:EE:FF")?.value == "aa-bb-cc-dd-ee-ff")
    }

    @Test func compactFormIsNormalized() {
        #expect(BluetoothMAC("aabbccddeeff")?.value == "aa-bb-cc-dd-ee-ff")
    }

    @Test func wrongLengthIsRejected() {
        #expect(BluetoothMAC("aa-bb-cc") == nil)
        #expect(BluetoothMAC("aa-bb-cc-dd-ee-ff-00") == nil)
    }

    @Test func nonHexIsRejected() {
        #expect(BluetoothMAC("zz-bb-cc-dd-ee-ff") == nil)
    }

    @Test func spacesAreRejected() {
        #expect(BluetoothMAC("aa bb cc dd ee ff") == nil)
    }

    /// Same canonical value — equal and same hash, whatever the input
    /// form was: the type is the picker's Hashable key.
    @Test func equalityIgnoresTheInputForm() {
        #expect(BluetoothMAC("aa-bb-cc-dd-ee-ff") == BluetoothMAC("AA:BB:CC:DD:EE:FF"))
        #expect(BluetoothMAC("aa-bb-cc-dd-ee-ff")?.hashValue
            == BluetoothMAC("aabbccddeeff")?.hashValue)
    }

    @Test func descriptionIsTheCanonicalForm() {
        #expect(BluetoothMAC("AA:BB:CC:DD:EE:FF")?.description == "aa-bb-cc-dd-ee-ff")
    }

    /// The forgiving AppConfig decode never takes this path (it reads
    /// the string itself), but a direct decode must be honest: valid
    /// values decode, malformed ones throw.
    @Test func directDecodeRoundtrips() throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: "aa-bb-cc-dd-ee-ff", format: .xml, options: 0)
        #expect(
            try PropertyListDecoder().decode(BluetoothMAC.self, from: data)
                == BluetoothMAC("aa-bb-cc-dd-ee-ff"))
    }

    @Test func directDecodeOfMalformedValueThrows() {
        let data = try! PropertyListSerialization.data(
            fromPropertyList: "not-a-mac", format: .xml, options: 0)
        #expect(throws: DecodingError.self) {
            try PropertyListDecoder().decode(BluetoothMAC.self, from: data)
        }
    }
}
