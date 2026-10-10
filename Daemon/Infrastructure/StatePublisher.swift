import CoreFoundation
import Foundation
import Shared

/// Publishes the live state (equalizer bands) into
/// `Paths.stateURL` a few times a second. Driven by a CFRunLoop timer
/// on the daemon's main run loop — the slices in DaemonLoop.run pump
/// it; no GCD, no extra threads. Write failures are logged once and
/// the publisher keeps going: the state file is a convenience, not a
/// contract.
public final class StatePublisher {
    private let monitor: SystemAudioMonitor
    private let speakerGate: SpeakerOutputMonitor
    /// The current speaker MAC — the loop owns the hot-reloaded config.
    private let macProvider: () -> String?
    private var timer: CFRunLoopTimer?
    private var failureLogged = false

    public init(
        monitor: SystemAudioMonitor,
        speakerGate: SpeakerOutputMonitor,
        macProvider: @escaping () -> String?
    ) {
        self.monitor = monitor
        self.speakerGate = speakerGate
        self.macProvider = macProvider
    }

    /// Installs the timer on the current run loop (the daemon main).
    public func start() {
        guard timer == nil else { return }
        var context = CFRunLoopTimerContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        let timer = CFRunLoopTimerCreate(
            nil, CFAbsoluteTimeGetCurrent() + 0.1, 0.1, 0, 0,
            { _, info in
                guard let info else { return }
                let publisher = Unmanaged<StatePublisher>
                    .fromOpaque(info).takeUnretainedValue()
                publisher.publish()
            },
            &context)
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .defaultMode)
        self.timer = timer
    }

    public func stop() {
        guard let timer else { return }
        CFRunLoopRemoveTimer(CFRunLoopGetCurrent(), timer, .defaultMode)
        self.timer = nil
    }

    private func publish() {
        // The bands reflect the SPEAKER, not the whole mix: when the
        // output targets another device — or the speaker's CoreAudio
        // device is gone (powered off) — the equalizer dies. The gate
        // reads open only without a configured speaker.
        let gated = (speakerGate.isRunning(mac: macProvider()) ?? true)
            ? monitor.snapshotBands()
            : [Double](repeating: 0, count: AudioBands.bandCount)
        let state = LiveState(
            bands: gated,
            updatedAt: Date())
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        do {
            let data = try encoder.encode(state)
            try data.write(to: Paths.stateURL, options: .atomic)
            failureLogged = false
        } catch {
            if !failureLogged {
                DaemonLog.print(
                    "state publish failed: \(String(describing: error))")
                failureLogged = true
            }
        }
    }
}
