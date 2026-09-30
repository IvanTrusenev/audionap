# CI

Two GitHub Actions workflows in `.github/workflows/` keep the repo honest on
a clean machine: `ci.yml` checks every change, `release.yml` publishes
releases from version tags.

## ci.yml — every push and PR

Triggers: `push` to `main`, `pull_request`. Three steps on `macos-latest`:

1. **Shared package tests** — `cd Shared && swift test` (71 tests). The
   package runs through `swift test` directly because Xcode 27 does not
   expose SPM test targets to test plans without a workspace.
2. **App tests** — `xcodebuild -scheme AudioNap test` (the
   `AudioNapTests` bundle: DaemonStatusTests). The app target's own tests
   do run through xcodebuild; only the SPM package needs the direct route.
3. **Daemon build** — `xcodebuild -scheme audionapd build`, a compile
   smoke check.

Results appear as a green check (or a red cross with logs) next to each
commit and PR. Clicking through in the **Actions** tab shows the step logs;
**Re-run jobs** repeats a run without a new push.

## release.yml — version tags publish releases

Trigger: `push` of a tag matching `v*`. It:

1. derives the version by stripping the `v` prefix from the tag,
2. runs `./scripts/release.sh <version>` — the same script used locally:
   universal build, verification gates, version consistency checks, and
   `dist/` packaging,
3. publishes the GitHub release with the three assets
   (`AudioNap-<version>.zip`, `audionapd-<version>.zip`, `SHA256SUMS.txt`)
   through the preinstalled `gh` CLI — **as a draft**: a human checks the
   assets and clicks Publish, so a broken first run can't end up public.

The only credential is the built-in `github.token` (permissions:
`contents: write`); no repository secrets are needed. A tag that disagrees
with the version in the code fails at the release.sh consistency check.

After the release, the only manual step left is updating the Homebrew
cask: `version` and `sha256` (the latter from the published
`SHA256SUMS.txt`).

## Where to change what

- **Workflow steps and triggers** — `.github/workflows/ci.yml` and
  `.github/workflows/release.yml`. This is the first place to look when CI
  does (or stops doing) something.
- **What a release contains** — `scripts/build.sh` (build + gates) and
  `scripts/release.sh` (version checks + packaging). Changing them affects
  both local `just build`/`just release` runs and CI identically.
- **Version rules** — `release.sh` asserts the tag against
  `AppIdentity.version`, the app bundle, and `audionapd --version`.
- **Test commands** — ci.yml; note the SPM-vs-xcodebuild split explained
  above, it exists for a toolchain reason.

## Keeping CI quiet

CI on every commit to `main` is intentional: each commit is provably green
and broken ones are easy to find. If unrelated commits (docs, README)
start wasting runs, add a path filter to the `push` trigger in `ci.yml`:

```yaml
on:
  push:
    branches: [main]
    paths:
      - "Shared/**"
      - "Daemon/**"
      - "App/**"
      - "Tests/**"
      - "AudioNap.xcodeproj/**"
      - ".github/workflows/**"
```

`pull_request` triggers stay unfiltered — every PR should be checked.
