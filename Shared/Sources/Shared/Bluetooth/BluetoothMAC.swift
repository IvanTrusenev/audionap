import Foundation

/// A Bluetooth MAC address and its canonical blueutil form.
public enum BluetoothMAC {

    /// Accepts `aa-bb-cc-dd-ee-ff`, `aa:bb:cc:dd:ee:ff` or
    /// `aabbccddeeff`, case-insensitive, and returns the canonical
    /// `aa-bb-cc-dd-ee-ff` blueutil form — or nil when the input is not
    /// a MAC address. The manual entry in the device picker runs through
    /// this before the value reaches the config.
    public static func normalize(_ input: String) -> String? {
        let compact =
            input
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")

        guard compact.count == 12, compact.allSatisfy(\.isHexDigit) else {
            return nil
        }

        let pairs = stride(from: 0, to: 12, by: 2).map { offset in
            let start = compact.index(compact.startIndex, offsetBy: offset)
            let end = compact.index(start, offsetBy: 2)
            return String(compact[start..<end])
        }

        return pairs.joined(separator: "-").lowercased()
    }
}
