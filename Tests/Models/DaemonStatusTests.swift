import Testing

@testable import AudioNap

struct DaemonStatusTests {

    @Test func startFromStoppedBeginsStarting() {
        #expect(DaemonStatus.next(from: .stopped, event: .operationStarted) == .starting)
    }

    @Test func startFromRunningBeginsStopping() {
        #expect(DaemonStatus.next(from: .running, event: .operationStarted) == .stopping)
    }

    @Test func operationStartedDuringTransitionStays() {
        #expect(DaemonStatus.next(from: .starting, event: .operationStarted) == .starting)
        #expect(DaemonStatus.next(from: .stopping, event: .operationStarted) == .stopping)
    }

    @Test func settledRunningEndsTransition() {
        #expect(
            DaemonStatus.next(from: .starting, event: .operationSettled(running: true))
                == .running
        )
    }

    @Test func settledStoppedEndsTransition() {
        #expect(
            DaemonStatus.next(from: .stopping, event: .operationSettled(running: false))
                == .stopped
        )
    }

    @Test func onlyTransitionsReportTransitioning() {
        #expect(DaemonStatus.starting.isTransitioning)
        #expect(DaemonStatus.stopping.isTransitioning)
        #expect(!DaemonStatus.running.isTransitioning)
        #expect(!DaemonStatus.stopped.isTransitioning)
    }
}
