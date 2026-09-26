# Code style

Conventions for contributing to AudioNap. This document is living — update it
when the team agrees on a new convention.

## Language and platform

- All code, comments, log messages, and docs are in English

- Swift 6 language mode (strict concurrency) on the Swift 6.4 compiler (Xcode 27)
- macOS 14+, universal binaries (Apple Silicon + Intel)
- SwiftPM manifests: `swift-tools-version: 6.2`, `swiftLanguageModes: [.v6]`

## Architecture

- UI: SwiftUI + Observation (`@Observable`, `@Environment`) — no
  `ObservableObject`/Combine in new code
- App architecture: light MVVM — View + `@MainActor @Observable` ViewModel +
  Services; dependencies passed via `init`, no DI containers
- Business logic: pure functions/types in the `Shared` package, testable without
  mocks
- Protocols at system boundaries (`DeviceSource` etc.) so real implementations
  can be substituted in tests
- No third-party dependencies except `swift-argument-parser` (CLI) and the
  `blueutil` binary

## File organization

1. One standalone type per file, named after the type (`AppConfig.swift`)
2. Nested types stay in the parent's file (`StayReason` lives in
   `DaemonDecision.swift`)
3. Extensions live in the type's file while they are few and about the type;
   once the type grows, split by responsibility:
   `AppConfig+Validation.swift`, `AppConfig+Persistence.swift`
4. Group files into domain folders inside the target
   (`Sources/Shared/Config/`, `Tests/SharedTests/Config/`). Folders are
   navigational only — one module, all `public` members visible. Graduate a
   domain to its own target only when it needs real isolation

## Swift idioms

- `let` by default, `var` only when the value changes
- Value types by default: `struct`/`enum` unless reference semantics are needed
- Declare `Sendable` explicitly on types that cross concurrency boundaries
- Units of measurement go into the name: `silenceTimeoutMinutes` vs
  `silenceTimeoutSeconds`; keep each unit conversion in exactly one place
- Document public API with `///` comments; explain *why*, not what
- Public API returns named types, not tuples — tuples are for short-lived
  values internal to a function
- Log through `os.Logger` with subsystem `online.threealab.audionap`

## Testing

- Framework: Swift Testing (`@Test`, `#expect`)
- Pure logic (`DaemonDecision.evaluate`, `AppConfig.normalized`) — table-style
  tests: inputs → expected decision
- Package tests run via `swift test` in `Shared/` (Xcode does not expose SPM
  test targets in test plans without a workspace); project tests run via the
  app scheme
- Coverage: aim for full coverage of the core; numbers in tests are explicit
  scenario inputs, not magic — tests must not reuse production constants
  ```bash
  cd Shared
  ./Scripts/coverage.sh          # tests + coverage table
  ./Scripts/coverage.sh --html   # also open a highlighted report in the browser
  ```

## Git

- See [CONTRIBUTING.md](CONTRIBUTING.md) — English, imperative mood, one
  logical change per commit
- Never commit build artifacts: `.build/`, `DerivedData/`, `xcuserdata/`
  (covered by `.gitignore`; keep the exception for
  `.swiftpm/xcshareddata/`)
