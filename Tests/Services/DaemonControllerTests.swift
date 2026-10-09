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
}
