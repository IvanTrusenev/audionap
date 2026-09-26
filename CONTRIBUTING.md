# Contributing to AudioNap

Thanks for your interest! The project is young — a full guide will come with the
first release.

## Project layout

| Directory | Contents |
|-----------|----------|
| `App/` | SwiftUI menu bar app (target `AudioNap`) |
| `Daemon/` | Headless daemon (target `audionapd`) |
| `Tests/` | Unit tests (target `AudioNapTests`) |

## Build & test

```bash
xcodebuild -project AudioNap.xcodeproj -scheme AudioNap test
xcodebuild -project AudioNap.xcodeproj -scheme audionapd build
```

## Commit conventions

- Commits in English, imperative mood, short subject
- One logical change per commit

## Code style

Conventions live in [STYLE.md](STYLE.md).

## License

MIT — see [LICENSE](LICENSE).
