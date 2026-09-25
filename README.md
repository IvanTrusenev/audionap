# AudioNap

Menu bar app for macOS that puts your Bluetooth speaker to sleep when you are away.

Bluetooth speakers suspend their own auto-off timer while a Bluetooth
connection is active. macOS holds that connection open even in silence, so the
speaker never sleeps. AudioNap watches for silence (MediaRemote + "Playing audio"
power assertion) and user inactivity, then drops the Bluetooth connection — and
the speaker's own firmware timer does the rest.

> **Status: work in progress.** The daemon is being ported from a proven
> prototype; first release is on the way.

## Components

| Component | Description |
|-----------|-------------|
| `AudioNap.app` | SwiftUI menu bar app: start/stop the daemon, pick a device, tune timeouts, view logs |
| `audionapd` | Headless daemon (launchd agent): disconnects the speaker after N minutes of silence + inactivity |

## How it works

```
every 30 s:
  playing = MediaRemote now-playing OR "Playing audio" power assertion
  idle    = seconds since last user input
  quiet for N minutes + idle → blueutil disconnect
speaker's own 15-minute timer → powers off
```

## Build

Requirements: macOS 14+, Xcode 16+.

```bash
git clone https://github.com/IvanTrusenev/audionap.git
cd audionap
open AudioNap.xcodeproj
```

or

```bash
xcodebuild -project AudioNap.xcodeproj -scheme AudioNap -configuration Release build
xcodebuild -project AudioNap.xcodeproj -scheme audionapd -configuration Release build
```

## Dependencies

- [blueutil](https://github.com/toy/blueutil) (`brew install blueutil`) — Bluetooth connection management

## License

[MIT](LICENSE)
