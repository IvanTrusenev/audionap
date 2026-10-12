import Foundation

/// Parses blueutil's output — one type per tool, a method per command:
/// the `--is-connected` answer and the `--paired` device list.
public enum BlueutilParser {

    /// The answer to `blueutil --is-connected <mac>` — "1" (connected)
    /// or "0"; returns true only for the trimmed "1".
    public static func isConnected(output: String) -> Bool {
        output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }

    /// Devices from `blueutil --paired` in output order; malformed
    /// lines are skipped. A line reads
    /// `address: aa-bb-cc-dd-ee-ff, not connected, not favourite,
    /// paired, name: "Foo", recent access date: …`
    public static func pairedDevices(output: String) -> [BlueutilDevice] {
        output.split(separator: "\n").compactMap { line in
            parse(line: String(line))
        }
    }

    private static func parse(line: String) -> BlueutilDevice? {
        guard let address = address(in: line), let name = name(in: line) else {
            return nil
        }

        return BlueutilDevice(
            address: address,
            name: name,
            connected: connected(in: line),
        )
    }

    /// The first MAC-looking token in the line, as a validated address.
    private static func address(in line: String) -> BluetoothMAC? {
        guard let match = line.firstMatch(of: RegexPatterns.blueutilAddress) else {
            return nil
        }
        return BluetoothMAC(String(match.1))
    }

    /// The text between the first pair of quotes after `name:`.
    private static func name(in line: String) -> String? {
        guard let match = line.firstMatch(of: RegexPatterns.blueutilName) else {
            return nil
        }
        return String(match.1)
    }

    /// True when the line reports the device as connected (as opposed
    /// to "not connected").
    private static func connected(in line: String) -> Bool {
        line.firstMatch(of: RegexPatterns.blueutilConnected) != nil
    }
}
