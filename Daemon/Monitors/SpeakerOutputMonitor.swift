import CoreAudio
import Foundation
import Shared

/// Answers "is the configured speaker the current output target" from
/// CoreAudio — the per-device gate for the universal playing signal.
/// Resolves the speaker's output device by MAC (UID `<MAC>:output`)
/// and reads its `DeviceIsRunningSomewhere` property. The device ID is
/// cached per MAC and re-resolved when the cached device stops
/// answering (e.g. after a disconnect/reconnect).
public final class SpeakerOutputMonitor {
    private var cachedMAC: String?
    private var cachedDeviceID: AudioDeviceID?

    /// Whether the speaker's output device is currently running; nil
    /// only when there is no configured MAC. A MAC whose CoreAudio
    /// device is missing (the speaker powered off or disconnected)
    /// reads as false — no device means no audio can reach it, so a
    /// disappearance is information, not blindness.
    public func isRunning(mac: String?) -> Bool? {
        guard let mac, let normalized = BluetoothMAC.normalize(mac) else {
            return nil
        }

        let deviceID: AudioDeviceID
        if let cached = cachedDeviceID, cachedMAC == normalized {
            deviceID = cached
        } else if let resolved = Self.resolveOutputDevice(mac: normalized) {
            cachedMAC = normalized
            cachedDeviceID = resolved
            deviceID = resolved
        } else {
            cachedMAC = nil
            cachedDeviceID = nil
            return false
        }

        guard let running = Self.isRunningSomewhere(deviceID) else {
            // The cached device went away (power-off, disconnect) —
            // drop the cache so the next poll resolves it anew.
            cachedMAC = nil
            cachedDeviceID = nil
            return false
        }
        return running != 0
    }

    /// Finds the output device whose UID matches the speaker MAC.
    private static func resolveOutputDevice(mac: String) -> AudioDeviceID? {
        allDevices().first { deviceID in
            guard let uid = readString(deviceID, kAudioDevicePropertyDeviceUID) else {
                return false
            }
            return SpeakerDeviceUID.isSpeakerOutput(uid: uid, mac: mac)
        }
    }

    private static func isRunningSomewhere(_ deviceID: AudioDeviceID) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var value = UInt32(0)
        let status = AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private static func allDevices() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(0)
        AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        var devices = [AudioDeviceID](
            repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices)
        return devices
    }

    private static func readString(
        _ objectID: AudioObjectID, _ selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var value: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, pointer)
        }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}
