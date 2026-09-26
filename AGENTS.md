# Instructions for AI agents working on AudioNap

AudioNap is an open-source macOS utility: a menu bar app (SwiftUI) and a daemon
(`audionapd`) that disconnects a Bluetooth speaker after N minutes of silence and
user inactivity, letting the speaker's own power-off timer finish the job.

## Working with this repo

- The repo owner performs git commits, pushes, and Xcode UI steps. The agent
  writes code, explains changes, and gets explicit approval before acting
  beyond the agreed step.
- Increment format: plan the piece → explain the concepts before code → code →
  walk through the result file by file → tests → owner commits.
- Keep project docs up to date after every significant change.
- Code, comments, log messages, docs, and commit messages are in English;
  commits are imperative-mood, one logical change each (see CONTRIBUTING.md).

## Key decisions (do not reopen without cause)

- Stack: Swift 6 language mode (Swift 6.4 / Xcode 27), SwiftUI + Observation,
  light MVVM, local Swift package `Shared` as the pure core,
  swift-argument-parser for the CLI, Swift Testing, os.Logger. No
  TCA/VIPER/Combine/GCD. Code conventions: STYLE.md.
- Playback detection: `playing = assertion("Playing audio") || mediaRemoteRate > 0.5`,
  with input activity as a safety net. MediaRemote is a private API: dlopen only,
  guard every dlsym, register (`MRMediaRemoteRegisterForNowPlayingNotifications`)
  strictly BEFORE the getter (segfault otherwise). nowplaying-cli is an optional
  fallback — never bundle (GPL).
- The daemon main loop is a run loop (`CFRunLoopRunInMode`), not sleep: it pumps
  the main queue where MediaRemote delivers callbacks. SIGTERM → clean exit.
- launchd label / bundle IDs: `online.threealab.audionap(.daemon)`; config at
  `~/Library/Application Support/AudioNap/config.plist` (atomic writes; invalid
  values → defaults + log, never crash).
- Legacy agent `com.ivantrusenev.bt-speaker-idle` stays on the Mac mini until
  migration (after M3); `--test-once` never disconnects.
- Package tests run via `swift test` in `Shared/` (Xcode 27 does not expose SPM
  test targets in test plans without a workspace; verified 2026-09-26).

## Progress

M0 ✓ research; M1 ✓ skeleton (App/Daemon/Tests folders, shared schemes, public
repo); M2.1 ✓ Shared package (AppConfig, DaemonDecision, LogLevel; 14 tests).
Next: M2.2 (Paths, LaunchAgentSpec) → M2.3 (link into audionapd, CLI) →
M2.4 (monitors) → M2.5 (ConfigWatcher, run loop) → M2.6 (live check on the
Mac mini). Reference implementation: bt-speaker-idle.
