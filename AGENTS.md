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

## Debugging

Live debugging is instrumented: the agent prepares the scenario and places
tracing points itself — the owner runs the scenario, the agent reads the full
picture from the logs. If the agent has to ask what the owner sees, the
instrumentation is missing. Tracing goes through `DevLog`
(`App/Services/DevLog.swift`): set `devLogSignature` per session (version it
per fix iteration), emit points with `DevLog.log(name, message)`, collect
with `log stream --predicate 'subsystem == "online.threealab.audionap" AND
category == "<signature>"'` (via `/usr/bin/log` — zsh's built-in `log`
conflicts). Reset the signature to `""` and remove the points afterwards.

## Progress

M0 ✓ research; M1 ✓ skeleton (App/Daemon/Tests folders, shared schemes, public
repo); M2 ✓ daemon (Shared package: AppConfig, DaemonDecision, monitors,
ConfigWatcher, run loop; live run 2026-09-26 showed the full
silence+idle→disconnect cycle); M3 ✓ menu bar app (status, Start/Stop,
hot config sliders, log tail). M4 ✓ device picker (blueutil list + manual
MAC), connect/disconnect toggle, ignoreUserActivity toggle; live e2e
2026-09-28: silence+idle → disconnect → speaker powered off by its own
timer. M5 ✓ packaging + release (2026-10-01): unified version 0.1.0, daemon
embedded in the app bundle with a self-provisioning installer, app icon,
universal build.sh and release.sh (dist/ zips + SHA256SUMS), README
install docs, first GitHub release v0.1.0, and the Homebrew tap
ivantrusenev/audionap with a cask (style/audit clean; install and the
Gatekeeper flow verified live). M6 ✓ CI (2026-10-01): ci.yml runs the
Shared package tests via swift test, the app test bundle and the daemon
build via xcodebuild on every push/PR; release.yml runs release.sh on v*
tags and drafts a GitHub release for a human to publish (docs/ci.md);
CI is green on main. M7 ✓ autostart (2026-10-09): RunAtLoad in the
launch agent spec, an AutostartController managing a copy of the
canonical plist in ~/Library/LaunchAgents/ (presence = autostart on,
no launchctl calls), a launch-at-login toggle in settings (default OFF,
state read from the filesystem); verified live: ON → the copy matches
the canonical plist, the toggle survives app restarts, after
logout/login launchd starts the daemon by itself (state running), and
the off-path works too (OFF → the copy is removed → next login: no
record, the daemon does not start; a manually removed copy shows OFF
in the toggle). Launchd hardening (2026-10-09/10, verified live with
unified-log instrumentation): start()/stop() carry a transition guard
against double-clicks, the bootstrap retry trusts launchd per attempt
with a 7s deadline (covers launchd's 5s exit-timeout), the daemon loop
sleeps in 1s slices so SIGTERM is noticed within a second instead of
losing the race to launchd's exit-timeout SIGKILL — the daemon now
exits cleanly and logs "stopped cleanly" — and LaunchctlParser treats
the spawn window (state = xpcproxy) as running, so the button no
longer flashes "stopped" right after a successful start. v0.2.0 ✓
released (2026-10-10): the first release built by release.yml (tag →
universal build via release.sh → draft → human publish), the cask
bumped to 0.2.0 (style/audit clean), and the live brew upgrade
verified end to end (app 0.2.0, the daemon reinstalled via the
version marker and running, Stop/Start quick and clean). Left for a
convenient moment: the uninstall --zap cycle (with a config backup)
and the manual zip path.
