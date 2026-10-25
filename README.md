# AudioNap

Menu bar app for macOS that puts your Bluetooth speaker to sleep when you are away.

Bluetooth speakers suspend their own auto-off timer while a Bluetooth
connection is active. macOS holds that connection open even in silence, so the
speaker never sleeps. AudioNap watches whether audio is actually reaching the
speaker — from any app — plus user inactivity, then drops the Bluetooth
connection, and the speaker's own firmware timer does the rest.

## Components

| Component | Description |
|-----------|-------------|
| `AudioNap.app` | SwiftUI menu bar app: start/stop the daemon, pick a device, tune timeouts, view logs, live VU-meter equalizer |
| `audionapd` | Headless daemon (launchd agent): disconnects the speaker after N minutes of silence + inactivity |

## How it works

```
every pollSeconds (default 10 s):
  playing = the speaker's CoreAudio device is the output target AND the
            captured system audio mix is active (universal: music, calls,
            browsers — any source)
  idle    = seconds since last user input
  quiet for N minutes + idle → blueutil disconnect
speaker's own 15-minute timer → powers off
```

When the audio capture is unavailable (no permission, no display), the
daemon falls back to the legacy "Playing audio" power-assertion signal.

## Configuration

The daemon reads `~/Library/Application Support/AudioNap/config.plist`;
the app writes it atomically and invalid values fall back to defaults.

| Key | Default | Meaning |
|---|---|---|
| `silenceTimeoutMinutes` | 15 | Silence minutes before the disconnect (1–30) |
| `inputWindowMinutes` | 15 | Recent-input minutes that keep the speaker connected (1–30) |
| `pollSeconds` | 30 | Daemon decision interval in seconds (10–120) |
| `speakerMAC` | — | The babysat speaker's MAC address |
| `ignoreUserActivity` | false | Count only silence, ignore input |
| `speakerOnBattery` | false | Disconnect only while the speaker runs on battery |
| `blueutilPath` | — | Absolute path to a custom `blueutil` install. When set and executable it wins over the standard prefixes and the PATH |
| `nowPlayingCLIPath` | — | Optional nowplaying-cli fallback (never bundled — GPL) |

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

### Audio capture permission

The daemon detects playback by capturing the system audio mix
(ScreenCaptureKit), which macOS groups under the Screen Recording category:

1. Start the daemon once — the first attempt requests the permission.
2. Open **System Settings → Privacy & Security → Screen & System Audio
   Recording** and enable **audionapd**.
3. Restart the daemon (Stop, then Start in the app) — the capture starts
   and the menu bar equalizer comes alive.

AudioNap never captures video — macOS simply files audio-only streams under
this category. Without the permission the daemon keeps working on the legacy
playback signal. Macs without a display (headless) cannot run the capture
either and use the same fallback.

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
just release 0.4.0    # dist/: AudioNap-0.4.0.zip, audionapd-0.4.0.zip, SHA256SUMS.txt
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
