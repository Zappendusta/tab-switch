# tab-switch

A macOS background agent that replaces the system window switcher with two keyboard-driven switchers:

- **Cmd+Tab** → switch between windows of **all apps** (replaces the native app switcher).
- **Option+Tab** → switch between windows of the **current app only**.

Both show a borderless text-list overlay (app icon + window title per row). Cycle with `Tab` / `Shift+Tab` while the modifier is held; the highlighted window is focused on release. Ordering is most-recently-used (MRU), so a single `Cmd+Tab` returns you to the previous window.

> **Built with AI.** This project — code, tests, design spec, and this README — was written by Claude (Anthropic's Claude Code). It is a personal tool, generated and iterated on through AI-assisted development.

## Why this exists

The native macOS `Cmd+Tab` switches between **applications**, not **windows**. If you have three browser windows, two terminals, and four editor windows open, the app switcher treats each app as a single entry — you land on *an* app and then have to fumble for the right window.

This tool flips the model: it switches between **windows** directly, regardless of which app owns them. The result is closer to the window-switching behavior on other platforms, with MRU ordering so the most common move (jump to the last window, jump back) is a single keystroke.

It is deliberately minimal — a personal tool, not a product. No settings UI and no code signing; it builds from source and installs via Homebrew.

## Requirements

- macOS 13 (Ventura) or later
- Xcode or the Swift command-line tools (Homebrew builds the app from source)
- **Accessibility permission** — required for both the keyboard event tap and window control.

## Install

```bash
brew tap Zappendusta/tab-switch
brew trust zappendusta/tab-switch
brew install tab-switch
brew services start tab-switch
```

`brew trust` is required because Homebrew 6.0+ refuses to load formulae from
third-party taps until you trust them. `brew services start` launches the agent
now and auto-starts it at login. Then
grant **Accessibility** permission in **System Settings → Privacy & Security →
Accessibility**.

> tab-switch is built from source, so each `brew upgrade` produces a new binary
> identity. macOS's permission system (TCC) treats that as a new app, so you must
> re-grant Accessibility after every upgrade.

The app runs as a background agent (`LSUIElement`): no Dock icon, no menu bar item. On launch it checks for Accessibility trust; if missing, it prompts and polls until granted, then starts automatically.

## Usage

| Keys | Action |
|------|--------|
| `Cmd+Tab` | Open all-apps window switcher / step to next window |
| `Option+Tab` | Open current-app window switcher / step to next window |
| `Shift+Tab` (modifier held) | Step backward |
| Release modifier | Focus the highlighted window |
| `Esc` (modifier held) | Cancel without switching |

A quick `Cmd+Tab` + release just flips to the previous window with no UI flash — the overlay only renders after a short hold or on the second `Tab`.

## Development

```bash
swift build                              # build
swift test                               # run all tests (TabSwitchCore only)
swift test --filter MRUListTests         # run one test class
./scripts/make-app.sh [debug|release]    # build + bundle into tab-switch.app
```

`swift run TabSwitchApp` works, but the event tap requires the **binary** to be granted Accessibility, so the normal loop is `./scripts/make-app.sh && open tab-switch.app`.

### Architecture

Two SwiftPM targets, split by testability:

- **TabSwitchCore** — pure value/logic types, no AppKit or Accessibility imports, so it is unit-testable. The only target with tests.
- **TabSwitchApp** — the executable; all AppKit / Accessibility (AX) / CoreGraphics integration lives here.

The authoritative design is in [`docs/superpowers/specs/2026-06-27-tab-switch-design.md`](docs/superpowers/specs/2026-06-27-tab-switch-design.md). For a detailed map of the core types and app wiring, see [`CLAUDE.md`](CLAUDE.md).

## License

MIT — see [`LICENSE`](LICENSE).
