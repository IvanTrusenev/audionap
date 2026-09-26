import Foundation
import Testing

@testable import Shared

struct LaunchAgentSpecTests {
    private let spec: LaunchAgentSpec

    init() {
        spec = LaunchAgentSpec(
            label: "online.threealab.audionap.daemon",
            programPath: "/tmp/audionapd",
            standardOutPath: "/tmp/daemon.log",
            standardErrorPath: "/tmp/daemon-error.log"
        )
    }

    @Test func plistHasLabel() {
        #expect(spec.plist["Label"] as? String == "online.threealab.audionap.daemon")
    }

    @Test func plistHasProgramArguments() {
        #expect(spec.plist["ProgramArguments"] as? [String] == ["/tmp/audionapd"])
    }

    @Test func plistEnablesKeepAlive() {
        #expect(spec.plist["KeepAlive"] as? Bool == true)
    }

    @Test func plistHasStandardOutPath() {
        #expect(spec.plist["StandardOutPath"] as? String == "/tmp/daemon.log")
    }

    @Test func plistHasStandardErrorPath() {
        #expect(spec.plist["StandardErrorPath"] as? String == "/tmp/daemon-error.log")
    }

    @Test func plistSerializesAndDecodesBack() throws {
        let data = try spec.data()
        let decoded =
            try PropertyListSerialization.propertyList(
                from: data, options: [], format: nil) as? [String: Any]

        #expect(decoded?["Label"] as? String == spec.label)
        #expect(decoded?["ProgramArguments"] as? [String] == [spec.programPath])
        #expect(decoded?["KeepAlive"] as? Bool == true)
        #expect(decoded?["StandardOutPath"] as? String == spec.standardOutPath)
        #expect(decoded?["StandardErrorPath"] as? String == spec.standardErrorPath)
    }
}
