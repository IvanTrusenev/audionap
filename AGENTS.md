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
- The committed repo stays product-only. Experiments, research, and notes
  about unrelated tools live in `.workbench/` (personal notes, not
  committed); project docs carry no references to them.
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
- UI design tokens: semantic Color Sets in the app asset catalog, consumed via
  `AppTheme` injected through the environment; views reference meanings
  (`statusActive`), never raw hues, and generated asset symbols keep the
  references compile-time checked.
- App Info.plists live in `Config/` (per-configuration split): both carry
  `NSBluetoothAlwaysUsageDescription` (blueutil aborts under the TCC gate
  without it), release also carries `LSMultipleInstancesProhibited` (debug
  keeps it off so preview hosts can't block the Run loop).
- `--test-once` runs one detection pass and never disconnects.
- Package tests run via `swift test` in `Shared/` (Xcode 27 does not expose SPM
  test targets in test plans without a workspace; verified 2026-09-26).

## Progress

M0 ✓ research; M1 ✓ skeleton (App/Daemon/Tests folders, shared schemes, public
repo); M2 ✓ daemon (Shared package: AppConfig, DaemonDecision, monitors,
ConfigWatcher, run loop; live run 2026-09-26 showed the full
silence+idle→disconnect cycle); M3 ✓ menu bar app (status, Start/Stop,
hot config sliders, log tail). M4 ✓ device picker (blueutil list + manual
MAC), connect/disconnect toggle, ignoreUserActivity toggle; live e2e
2026-09-28: silence+idle → disconnect → speaker powered off by its own
timer. Next: M5 (packaging + release: build script, zips, GitHub release,
Homebrew tap).
