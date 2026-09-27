import Foundation

/// Parses the output of `blueutil --paired`:
/// `address: aa-bb-cc-dd-ee-ff, not connected, not favourite, paired,
/// name: "Foo", recent access date: …`
public enum BlueutilPairedParser {

    /// Devices in output order; malformed lines are skipped.
    public static func parse(output: String) -> [BlueutilDevice] {
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

    /// The first MAC-looking token in the line.
    private static func address(in line: String) -> String? {
        guard
            let match = line.firstMatch(
                of: /address: ([0-9a-fA-F]{2}(?:-[0-9a-fA-F]{2}){5})/
            )
        else { return nil }
        return String(match.1)
    }

    /// The text between the first pair of quotes after `name:`.
    private static func name(in line: String) -> String? {
        guard let match = line.firstMatch(of: /name: "([^"]*)"/) else {
            return nil
        }
        return String(match.1)
    }

    /// True when the line reports the device as connected (as opposed
    /// to "not connected").
    private static func connected(in line: String) -> Bool {
        line.firstMatch(of: /, (connected)/) != nil
    }
}
