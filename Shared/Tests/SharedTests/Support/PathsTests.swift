//
//  PathsTests.swift
//  Shared
//
//  Created by Ivan Trusenev on 26.09.2026.
//
import Testing

@testable import Shared

struct PathsTests {

    @Test func appSupportDirectoryHasExpectedLocation() {
        #expect(
            Paths.appSupportDirectory.pathComponents.suffix(3)
                == ["Library", "Application Support", "AudioNap"])
    }

    @Test func configURLPointsIntoAppSupportDirectory() {
        #expect(Paths.configURL.lastPathComponent == "config.plist")
    }

    @Test func daemonURLPointsIntoAppSupportDirectory() {
        #expect(Paths.daemonURL.lastPathComponent == "audionapd")
    }

    @Test func stateURLPointsIntoAppSupportDirectory() {
        #expect(Paths.stateURL.lastPathComponent == "state.plist")
    }

    @Test func launchAgentTemplateURLPointsIntoAppSupportDirectory() {
        #expect(Paths.launchAgentTemplateURL.lastPathComponent == "launchagent.plist")
    }

    @Test func launchAgentInstalledURLIsInLaunchAgents() {
        #expect(
            Paths.launchAgentInstalledURL.pathComponents.suffix(3)
                == ["Library", "LaunchAgents", "online.threealab.audionap.daemon.plist"])
    }

    @Test func logsDirectoryHasExpectedLocation() {
        #expect(
            Paths.logsDirectory.pathComponents.suffix(3)
                == ["Library", "Logs", "AudioNap"])
    }

    @Test func daemonLogURLPointsIntoLogsDirrectory() {
        #expect(Paths.daemonLogURL.lastPathComponent == "daemon.log")
    }

    @Test func daemonErrorLogURLPointsIntoLogsDirrectory() {
        #expect(Paths.daemonErrorLogURL.lastPathComponent == "daemon-error.log")
    }
}
