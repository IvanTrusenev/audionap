import Foundation

/// A Bluetooth MAC address in its canonical blueutil form
/// (`aa-bb-cc-dd-ee-ff`). Construction validates and normalizes, so a
/// `BluetoothMAC` value is always a real address — callers cannot hold
/// a malformed one the way a bare String allowed. Codable as a plain
/// string so the config format stays `speakerMAC = "aa-bb-..."`.
public struct BluetoothMAC: Equatable, Hashable, Sendable, Codable {
    /// The canonical form.
    public let value: String

    /// Accepts `aa-bb-cc-dd-ee-ff`, `aa:bb:cc:dd:ee:ff` or
    /// `aabbccddeeff`, case-insensitive — or nil when the input is not
    /// a MAC address. The manual device entry runs through this before
    /// the value reaches the config.
    public init?(_ input: String) {
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

        value = pairs.joined(separator: "-").lowercased()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let mac = BluetoothMAC(raw) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "not a MAC address: \(raw)")
        }
        self = mac
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

extension BluetoothMAC: CustomStringConvertible {
    public var description: String { value }
}
