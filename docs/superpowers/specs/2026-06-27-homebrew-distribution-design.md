# Homebrew distribution — design

## Goal

Make `tab-switch` installable via Homebrew, and open-source it under MIT. Today
the app is built locally with `scripts/make-app.sh` and the docs declare it a
personal tool with "no code signing, notarization, settings UI, or
distribution". This change adds a distribution path without adding signing or a
settings UI.

## Approach

Distribute as a **build-from-source Homebrew formula**, not a cask.

Rationale:

- The project is already a SwiftPM package, so a formula that runs
  `swift build` is short and natural.
- Building locally sidesteps Gatekeeper entirely. Quarantine and notarization
  only apply to *downloaded* artifacts; a binary compiled on the user's machine
  by the formula is never quarantined. No Apple Developer account, no
  notarization pipeline, no "app is damaged" dialogs.
- No need to host zipped `.app` artifacts.

Accepted cost: each from-source build is ad-hoc-signed with a fresh hash, so
**Accessibility must be re-granted after every `brew upgrade`** — the same TCC
behavior already documented for local rebuilds. Only a notarized,
stable-identity cask would avoid this, and signing/notarization is explicitly
out of scope.

## Topology

- **Source repo** — `github.com/Zappendusta/tab-switch` (this repo), public.
- **Tap repo** — new public repo `github.com/Zappendusta/homebrew-tab-switch`
  holding `Formula/tab-switch.rb`. The `homebrew-` prefix enables the
  `brew tap Zappendusta/tab-switch` shorthand.

Install UX:

```bash
brew tap Zappendusta/tab-switch
brew trust zappendusta/tab-switch  # Homebrew 6.0+ requires trusting third-party taps
brew install tab-switch
brew services start tab-switch     # launch now + auto-start at login
```

## The formula (`Formula/tab-switch.rb`)

- `desc`, `homepage` (the source repo), `license "MIT"`.
- `url` points at a GitHub release tarball
  (`.../archive/refs/tags/vX.Y.Z.tar.gz`) with its `sha256`.
- Optional `head "https://github.com/Zappendusta/tab-switch.git", branch: "main"`
  so `brew install --HEAD tab-switch` tracks `main`.
- `depends_on :macos` (≥ 13) and `depends_on xcode: :build` (Swift toolchain
  needed for `swift build`).
- `install`:
  1. `swift build --disable-sandbox -c release`.
  2. Assemble `tab-switch.app` by porting the bundle/Info.plist logic from
     `scripts/make-app.sh` into the formula (copy release binary into
     `Contents/MacOS/tab-switch`, write `Info.plist` with `LSUIElement`).
  3. Install the bundle under the Homebrew prefix and symlink
     `bin/tab-switch` → the bundle's executable.
- `service do … end`: a launchd service that runs the bundled binary with
  `keep_alive true` and `run_at_load true`, so `brew services` manages
  login-start and restart.
- `caveats`: instruct the user to grant **Accessibility** in
  System Settings → Privacy & Security → Accessibility, and warn that a
  `brew upgrade` rebuilds the binary so Accessibility must be re-granted.
- No bottle block — build from source on every install.

## Versioning / release flow

- Tag releases `vX.Y.Z`, starting at `v0.1.0`.
- Per release: push the tag, recompute the tarball `sha256`, bump `url`/`sha256`
  in the tap repo's formula. Manual, low ceremony.

## Licensing & doc posture changes (this repo)

- Add a top-level **`LICENSE`** file: MIT, `Copyright (c) 2026 tab-switch`.
- `README.md`:
  - Replace the "Personal tool. No license; not intended for distribution."
    section with MIT licensing.
  - Add a Homebrew install section (the `brew` commands above) as the primary
    install path; keep the from-source build under Development.
  - Drop the "No settings UI, no code signing, no distribution." framing where
    it now contradicts reality.
- `CLAUDE.md`: soften the "no code signing, notarization, settings UI, or
  distribution" line so docs stop contradicting the shipped distribution path.
  Signing/notarization/settings-UI remain out of scope by choice; distribution
  via Homebrew is now in scope.

## Out of scope (by choice)

- Code signing, notarization, Homebrew cask, Apple Developer account.
- Settings UI.
- Solving the Accessibility re-grant-on-upgrade cost — it is accepted, and
  documented in the formula `caveats`.
