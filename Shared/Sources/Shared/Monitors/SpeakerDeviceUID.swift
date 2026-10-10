import Foundation

/// Matches CoreAudio device UIDs against the configured speaker MAC.
/// A Bluetooth speaker appears as two devices, `<MAC>:input` (its
/// microphone side) and `<MAC>:output` (the playing side); only the
/// output side carries audio to the speaker.
public enum SpeakerDeviceUID {

    /// True when `uid` is the speaker's output device UID, e.g.
    /// `AC-EF-92-D8-A6-7B:output` for the MAC `ac-ef-92-d8-a6-7b`.
    public static func isSpeakerOutput(uid: String, mac: String) -> Bool {
        guard let normalized = BluetoothMAC.normalize(mac) else { return false }
        let compactUID = uid.lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
        let compactMAC = normalized.replacingOccurrences(of: "-", with: "")
        return uid.lowercased().hasSuffix(":output") && compactUID.hasPrefix(compactMAC)
    }
}
