//
//  Paths.swift
//  Shared
//
//  Created by Ivan Trusenev on 26.09.2026.
//
import Foundation

public enum Paths {
    public static let appSupportDirectory: URL =
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first!
        .appendingPathComponent("AudioNap")

    public static let configURL: URL =
        appSupportDirectory.appendingPathComponent("config.plist")

    public static let daemonURL: URL =
        appSupportDirectory.appendingPathComponent("audionapd")

    public static let stateURL: URL =
        appSupportDirectory.appendingPathComponent("state.plist")

    public static let launchAgentTemplateURL: URL =
        appSupportDirectory.appendingPathComponent("launchagent.plist")

    public static let launchAgentInstalledURL: URL =
        FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library")
        .appendingPathComponent("LaunchAgents")
        .appendingPathComponent("\(AppIdentity.bundleID).daemon.plist")

    public static let logsDirectory: URL =
        FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library")
        .appendingPathComponent("Logs")
        .appendingPathComponent("AudioNap")

    public static let daemonLogURL: URL =
        logsDirectory.appendingPathComponent("daemon.log")

    public static let daemonErrorLogURL: URL =
        logsDirectory.appendingPathComponent("daemon-error.log")
}
