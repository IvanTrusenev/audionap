import Testing

@testable import AudioNap

@MainActor
struct DaemonControllerTests {

    @Test func startIsANoOpDuringTransition() async {
        let controller = DaemonController(status: .starting)
        try? await controller.start()
        #expect(controller.status == .starting)
    }

    @Test func stopIsANoOpDuringTransition() async {
        let controller = DaemonController(status: .stopping)
        try? await controller.stop()
        #expect(controller.status == .stopping)
    }

    @Test func adoptAlivePromotesStopped() {
        let controller = DaemonController(status: .stopped)
        controller.adopt(alive: true)
        #expect(controller.status == .running)
    }

    @Test func adoptDeadDemotesRunning() {
        let controller = DaemonController(status: .running)
        controller.adopt(alive: false)
        #expect(controller.status == .stopped)
    }

    @Test func adoptMatchingIsANoOp() {
        let running = DaemonController(status: .running)
        running.adopt(alive: true)
        #expect(running.status == .running)

        let stopped = DaemonController(status: .stopped)
        stopped.adopt(alive: false)
        #expect(stopped.status == .stopped)
    }

    @Test func adoptDuringTransitionIsANoOp() {
        let starting = DaemonController(status: .starting)
        starting.adopt(alive: true)
        #expect(starting.status == .starting)

        let stopping = DaemonController(status: .stopping)
        stopping.adopt(alive: false)
        #expect(stopping.status == .stopping)
    }
}
