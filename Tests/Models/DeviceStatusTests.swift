import Testing

@testable import AudioNap

struct DeviceStatusTests {

    @Test func connectFromDisconnectedBeginsConnecting() {
        #expect(DeviceStatus.next(from: .disconnected, event: .operationStarted) == .connecting)
    }

    @Test func disconnectFromConnectedBeginsDisconnecting() {
        #expect(DeviceStatus.next(from: .connected, event: .operationStarted) == .disconnecting)
    }

    @Test func operationStartedDuringTransitionStays() {
        #expect(DeviceStatus.next(from: .connecting, event: .operationStarted) == .connecting)
        #expect(DeviceStatus.next(from: .disconnecting, event: .operationStarted) == .disconnecting)
    }

    @Test func settledConnectedEndsTransition() {
        #expect(
            DeviceStatus.next(from: .connecting, event: .operationSettled(connected: true))
                == .connected
        )
    }

    @Test func settledDisconnectedEndsTransition() {
        #expect(
            DeviceStatus.next(from: .disconnecting, event: .operationSettled(connected: false))
                == .disconnected
        )
    }

    @Test func onlyTransitionsReportTransitioning() {
        #expect(DeviceStatus.connecting.isTransitioning)
        #expect(DeviceStatus.disconnecting.isTransitioning)
        #expect(!DeviceStatus.connected.isTransitioning)
        #expect(!DeviceStatus.disconnected.isTransitioning)
    }
}
