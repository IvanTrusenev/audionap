import Foundation
import Testing

@testable import Shared

struct AppConfigTests {

    @Test func defaultsMatchPlan() {
        let config = AppConfig()
        // Defaults must match the type constants — the single source of truth
        // (init, decode, and normalization all reference them).
        #expect(config.speakerMAC == nil)
        #expect(config.silenceTimeoutMinutes == AppConfig.defaultSilenceTimeoutMinutes)
        #expect(config.inputWindowMinutes == AppConfig.defaultInputWindowMinutes)
        #expect(config.ignoreUserActivity == false)
        #expect(config.speakerOnBattery == AppConfig.defaultSpeakerOnBattery)
        #expect(config.pollSeconds == AppConfig.defaultPollSeconds)
        #expect(config.logLevel == AppConfig.defaultLogLevel)
    }

    // MARK: - Normalization

    @Test func outOfRangeSilenceTimeoutFallsBackToDefault() {
        var config = AppConfig()
        config.silenceTimeoutMinutes = 999
        let result = config.normalized()
        #expect(result.config.silenceTimeoutMinutes == AppConfig.defaultSilenceTimeoutMinutes)
        #expect(result.warnings.count == 1)
        #expect(result.warnings[0].contains("silenceTimeoutMinutes"))
    }

    @Test func outOfRangePollSecondsFallsBackToDefault() {
        var config = AppConfig()
        config.pollSeconds = 5  // below the minimum of 10
        let result = config.normalized()
        #expect(result.config.pollSeconds == AppConfig.defaultPollSeconds)
    }

    @Test func outOfRangeInputWindowFallsBackToDefault() {
        var config = AppConfig()
        config.inputWindowMinutes = 0  // below the minimum of 1
        let result = config.normalized()
        #expect(result.config.inputWindowMinutes == AppConfig.defaultInputWindowMinutes)
    }

    @Test func validValuesSurviveNormalization() {
        var config = AppConfig()
        config.silenceTimeoutMinutes = 15
        config.inputWindowMinutes = 10
        config.pollSeconds = 45
        let result = config.normalized()
        #expect(result.config == config)
        #expect(result.warnings.isEmpty)
    }

    // MARK: - Decode: tolerance

    @Test func unknownKeysAreTolerated() {
        // The plist contains keys AppConfig doesn't know — they're ignored
        let plist: [String: Any] = [
            "speakerMAC": "aa-bb-cc-dd-ee-ff",
            "silenceTimeoutMinutes": 7,
            "someFutureKey": "who knows",
            "anotherUnknownKey": 42,
        ]
        let data = try! PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let config = try! PropertyListDecoder().decode(AppConfig.self, from: data)
        #expect(config.speakerMAC == "aa-bb-cc-dd-ee-ff")
        #expect(config.silenceTimeoutMinutes == 7)
        #expect(config.inputWindowMinutes == AppConfig.defaultInputWindowMinutes)  // default
    }

    @Test func brokenPlistFallsBackToDefaults() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("broken-\(UUID().uuidString).plist")
        try! Data("not a plist".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let config = AppConfig.load(from: url)
        #expect(config == AppConfig())
    }

    // MARK: - Save/load roundtrip

    @Test func loadNormalizesInvalidValues() throws {
        // A readable plist with a value outside the range: load must fix it
        // and log a warning (not crash).
        var config = AppConfig()
        config.silenceTimeoutMinutes = 999
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("invalid-\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: url) }

        try config.save(to: url)
        let loaded = AppConfig.load(from: url)
        #expect(loaded.silenceTimeoutMinutes == AppConfig.defaultSilenceTimeoutMinutes)
    }

    @Test func roundtripPreservesValues() throws {
        var config = AppConfig()
        config.speakerMAC = "aa-bb-cc-dd-ee-ff"
        config.silenceTimeoutMinutes = 12
        config.inputWindowMinutes = 8
        config.ignoreUserActivity = true
        config.pollSeconds = 60
        config.logLevel = .debug

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: url) }

        try config.save(to: url)
        #expect(AppConfig.load(from: url) == config)
    }

    // MARK: - LogLevel: unknown strings must not break the config

    @Test func unknownLogLevelFallsBackToInfo() {
        let plist: [String: Any] = ["logLevel": "verbose"]
        let data = try! PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let config = try! PropertyListDecoder().decode(AppConfig.self, from: data)
        #expect(config.logLevel == .info)
    }
}
