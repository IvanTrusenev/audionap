import Foundation

/// The project's regex collection. Parsers reference these patterns by
/// name: before writing a new one, look here first — two patterns that
/// mean the same thing must never coexist. Names carry a domain prefix,
/// the collection itself is domain-neutral.
///
/// The patterns carry `nonisolated(unsafe)` because the stdlib `Regex`
/// is not Sendable in this toolchain — but matching is a pure,
/// read-only operation, so sharing one compiled pattern across threads
/// is safe (the same justification as `AudioBands.fft`).
public enum RegexPatterns {
    /// blueutil prints addresses in the dashed form; the pattern pins
    /// that output contract, the validation itself happens in
    /// `BluetoothMAC`.
    public nonisolated(unsafe) static let blueutilAddress =
        /address: ([0-9a-fA-F]{2}(?:-[0-9a-fA-F]{2}){5})/
    /// The device name between the first pair of quotes after `name:`.
    public nonisolated(unsafe) static let blueutilName = /name: "([^"]*)"/
    /// The comma-led state word in a `blueutil --paired` line.
    public nonisolated(unsafe) static let blueutilConnected = /, (connected)/
}
