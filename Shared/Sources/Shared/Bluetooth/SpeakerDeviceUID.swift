import Foundation

/// A CoreAudio device UID of a Bluetooth speaker. A speaker appears
/// to CoreAudio as two devices, `<MAC>:input` (its microphone side)
/// and `<MAC>:output` (the playing side) — only the output side
/// carries audio to the speaker.
public struct SpeakerDeviceUID: Equatable {
    public enum Side: String, CaseIterable {
        case input
        case output
    }

    /// The speaker's MAC in the canonical blueutil form.
    public let mac: String
    public let side: Side

    /// Parses a CoreAudio device UID; nil when the string is not a
    /// Bluetooth speaker UID (unknown side or an invalid MAC part).
    public static func parse(_ uid: String) -> SpeakerDeviceUID? {
        let lower = uid.lowercased()
        guard let side = Side.allCases.first(where: { lower.hasSuffix(":\($0.rawValue)") })
        else {
            return nil
        }
        let macPart = String(lower.dropLast(side.rawValue.count + 1))
        guard let mac = BluetoothMAC.normalize(macPart) else { return nil }
        return SpeakerDeviceUID(mac: mac, side: side)
    }
}
