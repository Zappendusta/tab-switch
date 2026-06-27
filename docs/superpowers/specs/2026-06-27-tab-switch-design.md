# tab-switch — Design Spec

**Date:** 2026-06-27
**Status:** Approved (design), pending implementation plan

## Summary

A macOS-only background app that adds two keyboard window switchers:

- **Option+Tab** → switch between windows of the **current app only**.
- **Cmd+Tab** → switch between windows of **all apps** (fully replaces the native macOS app switcher).

Both show a lightweight **text-list overlay** (app icon + window title per row), cycle with Tab / Shift+Tab while the modifier is held, and focus the highlighted window on release. Window order is **most-recently-used (MRU)**, so Tab-once returns to the previous window — classic alt-tab feel.

Scope: **personal minimal tool**. No code signing, notarization, settings UI, or distribution. Goal is the fastest path to a working, reliable tool on the author's Mac.

## Background

Native macOS cannot produce this behavior: `Cmd+Tab` switches *applications* (not windows) and is not remappable; `Cmd+`` ` `` cycles same-app windows but has no visual switcher. Existing third-party tools solve it but don't fit (AltTab gates multiple shortcuts behind a $9.99 Pro tier; HyperSwitch is unmaintained since 2021). See `.planning/research/2026-06-27-macos-window-switching-cmdtab-opttab.md`. This project builds a minimal personal replacement.

## Technical approach

**Native Swift + AppKit**, no third-party dependencies.

Rationale: replacing `Cmd+Tab` requires *consuming* the system event, which only a `CGEventTap` can do. Carbon `RegisterEventHotKey` (used by HotKey/Magnet libraries) cannot intercept Cmd+Tab; Hammerspoon cannot consume it either. So a native event tap is mandatory, which makes a dependency-free Swift/AppKit app the natural choice.

Only one system permission is required: **Accessibility** (no Screen Recording, since the overlay is a text list, not thumbnails).

## Components

A small AppKit background app (LSUIElement / agent app; optional minimal status item). Five focused pieces:

1. **HotkeyTap** — a `CGEventTap` on `keyDown` / `flagsChanged`. Detects `Cmd` and `Option` held, `Tab` / `Shift+Tab` presses, and modifier release. Consumes (swallows) Cmd+Tab and Option+Tab so the system never sees them. Emits semantic events: `open(scope)`, `next`, `prev`, `commit`, `cancel`.
2. **WindowStore** — enumerates windows via the Accessibility API (`NSWorkspace.runningApplications` → per-app `AXUIElement` → `AXWindows`). Serves two scopes: *all apps* (Cmd+Tab) and *active app only* (Option+Tab). Returns lists in MRU order; prunes closed windows lazily.
3. **MRUTracker** — observes `NSWorkspace.didActivateApplication` and AX focus changes to keep the MRU list current, so Tab-once returns to the previous window.
4. **SwitcherPanel** — a borderless floating `NSPanel` showing the text list (app icon + window title). Highlight moves with each Tab; appears on modifier-hold; dismisses and focuses the selection on release.
5. **Focuser** — raises the chosen window via `AXUIElementPerformAction(_, kAXRaiseAction)` and activates its owning app; un-minimizes if needed.

## Data flow (one switch cycle)

1. User holds **Cmd** (or **Option**) and taps **Tab**.
2. HotkeyTap sees modifier+Tab, **consumes** the event, emits `open(scope)`:
   - Cmd → scope = *all apps*
   - Option → scope = *active app only*
3. WindowStore returns the window list for that scope in MRU order; SwitcherPanel appears with row **1** (the previous window) pre-highlighted.
4. Each further **Tab** → `next` (Shift+Tab → `prev`); highlight moves, wrapping around. Panel stays up while the modifier is held.
5. User **releases the modifier** → `commit` → Focuser raises + activates the highlighted window → panel hides → MRUTracker moves that window to the front of the MRU list.
6. **Esc** while open → `cancel`; panel hides, no focus change.

**Flash-avoidance detail:** the panel renders only after a short hold (~150ms) OR immediately on the second Tab. A quick Cmd+Tab+release just flips to the previous window with no UI flash.

## Error handling & edge cases

- **Accessibility permission missing** — app is useless without it. On launch, check `AXIsProcessTrusted()`; if not granted, prompt and open System Settings → Privacy → Accessibility. Re-check on app activation.
- **CGEventTap disabled by the system** — listen for `tapDisabledByTimeout` / `tapDisabledByUserInput` and re-enable the tap automatically.
- **No windows in scope** — (e.g. Option+Tab with one window) show nothing / brief "no other windows"; do nothing on release.
- **Other Spaces / minimized / hidden windows** — include normal + minimized windows from the AX list; focusing a minimized window un-minimizes it; activating a window on another Space follows macOS default (Space switch). Skip titleless utility/off-screen windows.
- **App quits / window closes mid-switch** — Focuser validates the AXUIElement before raising; if invalid, fall through to the next item.
- **Stale MRU entries** — pruned lazily when building each list.

**Known risk:** enumerating all windows across all apps via the Accessibility API can be slow with many apps open, and some apps expose windows imperfectly. Acceptable for a personal tool; mitigation if laggy is to cache the list and refresh on app-activation events.

## Testing & verification

**Unit tests (pure logic only):**
- MRU ordering: move-to-front, prune closed.
- next/prev cycling with wrap-around.
- Scope filtering: active-app vs all-apps.

**Manual verification checklist:**
- Cmd+Tab shows all-apps windows; native switcher never appears.
- Option+Tab shows only active-app windows.
- Tab / Shift+Tab cycle and wrap correctly.
- Release focuses the highlighted window; Tab-once returns to previous (MRU).
- Esc cancels with no focus change.
- Quick Cmd+Tab+release flips to previous window with no UI flash.
- Minimized window un-minimizes on focus.
- Revoking Accessibility permission triggers the re-prompt.

**Out of scope:** automated UI/integration tests, CI, notarization, distribution.
