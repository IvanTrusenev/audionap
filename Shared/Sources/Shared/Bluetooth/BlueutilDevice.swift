import Foundation

/// One paired Bluetooth device as reported by `blueutil --paired`.
public struct BlueutilDevice: Equatable, Sendable {
    /// MAC in blueutil format (`aa-bb-cc-dd-ee-ff`).
    public let address: String
    /// The device's name, as set by its owner.
    public let name: String
    /// Whether blueutil reports the device as connected.
    public let connected: Bool
}
