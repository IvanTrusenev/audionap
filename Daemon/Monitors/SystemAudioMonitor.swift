import CoreMedia
import Foundation
import ScreenCaptureKit
import Shared

/// Captures the system audio mix (ScreenCaptureKit) and feeds the RMS
/// into an `ActivityWindow` — the universal "is sound playing" signal,
/// agnostic to the source app. Buffers arrive on ScreenCaptureKit's
/// own queue (`sampleHandlerQueue: nil` — no GCD in this codebase);
/// the state is guarded by a plain lock, which is safe because that
/// queue is not a realtime audio thread. The daemon's run loop only
/// reads the accumulated window.
public final class SystemAudioMonitor: NSObject, SCStreamOutput {
    private let lock = NSLock()
    private var window = ActivityWindow()
    private var stream: SCStream?
    /// Verified on the first buffer: the RMS math requires Float32
    /// (lpcm, 32-bit) — anything else disables the capture so the loop
    /// falls back to the legacy signals instead of trusting garbage.
    private var formatVerified = false
    private var formatIsFloat32 = false

    private(set) var isRunning = false
    /// Human-readable reason why the capture is not running, if any.
    private(set) var lastError: String?
    /// RMS of the most recent buffer — for the UI/equalizer later.
    private(set) var latestRMS = 0.0

    /// Starts the capture. Throws when the Screen Recording permission
    /// is missing (after requesting it) or the stream cannot start —
    /// the caller falls back to the legacy playing signals.
    public func start() async throws {
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            lastError = "screen capture permission required"
            throw SystemAudioMonitorError.permissionRequired
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            lastError = "no display found"
            throw SystemAudioMonitorError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        // No sampleRate/channelCount hints: they are requests the system
        // may ignore (the spike asked for 44.1k and got 48k). The RMS
        // math reads the actual buffers, and the first buffer's format
        // is verified against Float32 below.

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: nil)
        try await stream.startCapture()
        self.stream = stream
        isRunning = true
        lastError = nil
        DaemonLog.print("audio capture: active — universal playing signal")
    }

    /// Stops the capture.
    public func stop() async {
        try? await stream?.stopCapture()
        stream = nil
        isRunning = false
    }

    /// Whether the window reads as playing; nil while the capture is
    /// not running — the caller then falls back to legacy signals.
    public func isPlaying() -> Bool? {
        lock.lock()
        defer { lock.unlock() }
        guard isRunning else { return nil }
        return window.isPlaying(at: Date().timeIntervalSinceReferenceDate)
    }

    // MARK: - SCStreamOutput

    public func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .audio else { return }

        lock.lock()
        defer { lock.unlock() }
        if !formatVerified,
           let desc = CMSampleBufferGetFormatDescription(sampleBuffer),
           let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc) {
            formatVerified = true
            formatIsFloat32 = asbd.pointee.mFormatID == kAudioFormatLinearPCM
                && asbd.pointee.mBitsPerChannel == 32
            if !formatIsFloat32 {
                isRunning = false
                lastError = "unexpected audio format — legacy signals"
                DaemonLog.print("audio capture: unexpected format — legacy signals")
                return
            }
        }
        guard formatIsFloat32 else { return }

        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var length = 0
        var pointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(
            block, atOffset: 0, lengthAtOffsetOut: nil,
            totalLengthOut: &length, dataPointerOut: &pointer)
        guard let pointer, length > 0 else { return }

        let count = length / MemoryLayout<Float>.size
        let samples = UnsafeRawPointer(pointer).assumingMemoryBound(to: Float.self)
        var sum = 0.0
        for i in 0..<count { sum += Double(samples[i] * samples[i]) }
        let rms = (sum / Double(count)).squareRoot()

        latestRMS = rms
        window.mark(
            active: rms > ActivityWindow.defaultThreshold,
            at: Date().timeIntervalSinceReferenceDate)
    }
}

public enum SystemAudioMonitorError: Error, Sendable {
    case permissionRequired
    case noDisplay
}
