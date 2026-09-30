# AudioNap

Menu bar app for macOS that puts your Bluetooth speaker to sleep when you are away.

Bluetooth speakers suspend their own auto-off timer while a Bluetooth
connection is active. macOS holds that connection open even in silence, so the
speaker never sleeps. AudioNap watches for silence (the "Playing audio" power
assertion) and user inactivity, then drops the Bluetooth connection — and
the speaker's own firmware timer does the rest.

> **Status:** the first release, v0.1.0, is being packaged. The app and the
> daemon are feature-complete and have been running on the author's machine
> through the full silence → disconnect → power-off cycle.

## Components

| Component | Description |
|-----------|-------------|
| `AudioNap.app` | SwiftUI menu bar app: start/stop the daemon, pick a device, tune timeouts, view logs |
| `audionapd` | Headless daemon (launchd agent): disconnects the speaker after N minutes of silence + inactivity |

## How it works

```
every pollSeconds (default 10 s):
  playing = "Playing audio" power assertion (held by Chromium-family players)
  idle    = seconds since last user input
  quiet for N minutes + idle → blueutil disconnect
speaker's own 15-minute timer → powers off
```

## Install

### Homebrew (recommended)

```bash
brew tap ivantrusenev/audionap
brew install --cask audionap
```

blueutil is installed automatically as a dependency.

### Manual

1. Download `AudioNap-<version>.zip` from the latest GitHub release and unpack
   `AudioNap.app` into `/Applications`.
2. Install blueutil: `brew install blueutil`.

Power users: `audionapd-<version>.zip` is the standalone daemon for launchd
setups without the app.

### First launch (Gatekeeper)

AudioNap is ad-hoc signed and not notarized, so macOS blocks the first launch
("cannot verify the developer"). To allow it:

1. Open the app once, then dismiss the dialog.
2. Open **System Settings → Privacy & Security**, scroll to **Security**, and
   click **Open Anyway** next to AudioNap.

Repeat after every update — each ad-hoc signature is new, and macOS 15 and
later no longer offer the right-click override.

## Uninstall

```bash
brew uninstall --zap audionap
```

The zap removes the app, the daemon, its launch agent, configuration, and
logs. Manual removal:

```bash
launchctl bootout gui/$(id -u)/online.threealab.audionap.daemon
rm -rf ~/Library/Application\ Support/AudioNap ~/Library/Logs/AudioNap
```

## Build

Requirements: macOS 14+, Xcode 27+.

```bash
git clone https://github.com/IvanTrusenev/audionap.git
cd audionap
open AudioNap.xcodeproj
```

Release build and packaging from the command line:

```bash
just build            # universal Release app with verification gates
just release 0.1.0    # dist/: AudioNap-0.1.0.zip, audionapd-0.1.0.zip, SHA256SUMS.txt
```

or

```bash
xcodebuild -project AudioNap.xcodeproj -scheme AudioNap -configuration Release build
xcodebuild -project AudioNap.xcodeproj -scheme audionapd -configuration Release build
```

CI runs the tests and builds on every commit; version tags publish releases
automatically — see [docs/ci.md](docs/ci.md).

## Dependencies

- [blueutil](https://github.com/toy/blueutil) (`brew install blueutil`) — Bluetooth connection management

## License

[MIT](LICENSE)
