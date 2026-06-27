# Shift-to-Reverse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** While the switcher is open, pressing Tab always steps forward and tapping Shift steps backward — replacing the old Shift+Tab reverse gesture.

**Architecture:** A localized change to `HotkeyTap`, the CGEventTap layer. Tab's keyDown handler stops branching on Shift (always `next`). A new bit of state tracks the Shift modifier's down-transition in `flagsChanged` so each Shift press fires `prev` once. No public signatures change, so `AppController` and `SwitcherState` are untouched (`prev()` already exists and is unit-tested).

**Tech Stack:** Swift, AppKit, CoreGraphics (CGEventTap). macOS 13+.

---

## Behavior change

| Gesture | Before | After |
|---------|--------|-------|
| Hold modifier, press Tab | next (or prev if Shift held) | **next** (always) |
| Hold modifier, tap Shift | nothing on its own | **prev** (one step per press) |
| Hold modifier, Shift+Tab | prev | next (Tab ignores Shift now) — but you no longer need it |

"One step per press" means each *press* of Shift (its up→down transition) moves back once; holding Shift down does not repeat.

## File Structure

Only one file changes:

- Modify: `Sources/TabSwitchApp/HotkeyTap.swift` — Tab no longer branches on Shift; add Shift down-transition tracking in `flagsChanged` to trigger `prev`.

This is App-layer code that drives a live `CGEventTap` with real key events, so it cannot be unit-tested without the system event stream. It is verified manually, consistent with how the rest of the App layer was verified. The reverse logic itself (`SwitcherState.prev()` wrap-around) is already covered by `Tests/TabSwitchCoreTests/SwitcherStateTests.swift::testPrevWrapsAround`.

---

## Task 1: Shift tap reverses the switcher

**Files:**
- Modify: `Sources/TabSwitchApp/HotkeyTap.swift`

- [ ] **Step 1: Add Shift-state tracking**

In `Sources/TabSwitchApp/HotkeyTap.swift`, add a stored property next to the existing key-code constants. Change:

```swift
    private let tabKey: Int64 = 0x30      // Tab
    private let escKey: Int64 = 0x35      // Escape
```

to:

```swift
    private let tabKey: Int64 = 0x30      // Tab
    private let escKey: Int64 = 0x35      // Escape

    /// Tracks whether Shift was already held, so each Shift *press* (not hold)
    /// steps the switcher backward exactly once.
    private var shiftWasDown = false
```

- [ ] **Step 2: Make Tab always step forward; seed Shift state on open**

Replace this block (the Tab keyDown handler):

```swift
            if keyCode == tabKey && (cmd || option) {
                if delegate.isSessionOpen {
                    shift ? delegate.hotkeyPrev() : delegate.hotkeyNext()
                } else {
                    let scope: Scope = cmd ? .allApps : .activeApp
                    delegate.hotkeyOpen(scope: scope, reverse: shift)
                }
                return nil  // consume: system switcher never sees Cmd/Opt+Tab
            }
```

with:

```swift
            if keyCode == tabKey && (cmd || option) {
                if delegate.isSessionOpen {
                    delegate.hotkeyNext()
                } else {
                    let scope: Scope = cmd ? .allApps : .activeApp
                    delegate.hotkeyOpen(scope: scope, reverse: shift)
                    // Seed Shift state so an already-held Shift at open time does
                    // not immediately count as a fresh press in flagsChanged.
                    shiftWasDown = shift
                }
                return nil  // consume: system switcher never sees Cmd/Opt+Tab
            }
```

- [ ] **Step 3: Trigger prev on a Shift down-transition in flagsChanged**

Replace this block (the flagsChanged handler):

```swift
        if type == .flagsChanged && delegate.isSessionOpen {
            // Commit when both Cmd and Option are released.
            if !cmd && !option {
                delegate.hotkeyCommit()
            }
        }
```

with:

```swift
        if type == .flagsChanged && delegate.isSessionOpen {
            if !cmd && !option {
                // Activation modifier released → commit the selection.
                shiftWasDown = false
                delegate.hotkeyCommit()
            } else if shift && !shiftWasDown {
                // Fresh Shift press while still holding the activation modifier
                // → step backward once.
                delegate.hotkeyPrev()
                shiftWasDown = true
            } else {
                shiftWasDown = shift
            }
        }
```

- [ ] **Step 4: Build and bundle**

Run:

```bash
cd /Users/paulusdettmer/tab-switch
swift build
./scripts/make-app.sh debug
```

Expected: `Build complete!` then `Built tab-switch.app`, no errors.

- [ ] **Step 5: Manual verification**

Run the app (grant Accessibility if prompted; it auto-starts once granted):

```bash
pkill -f tab-switch || true
open tab-switch.app
```

With at least 3 windows in scope, verify:

- [ ] **Cmd+Tab**, then keep tapping **Tab** → highlight moves forward and wraps (unchanged).
- [ ] While holding **Cmd** with the overlay open, **tap Shift** → highlight moves **backward** one step per tap, wrapping past the top to the bottom.
- [ ] **Holding** Shift down (without re-tapping) does **not** keep moving backward — it steps once per press.
- [ ] Releasing **Cmd** still focuses the highlighted window.
- [ ] The same Shift-to-reverse works during an **Option+Tab** (same-app) session.
- [ ] **Esc** still cancels.

To stop the agent: `pkill -f tab-switch`

- [ ] **Step 6: Commit**

```bash
git add Sources/TabSwitchApp/HotkeyTap.swift
git commit -m "feat(app): tap Shift to reverse the switcher instead of Shift+Tab"
```

---

## Notes

- **Why track `shiftWasDown`:** `flagsChanged` fires continuously while a modifier is held, so without an edge check a single Shift press would step backward repeatedly. Tracking the previous state turns the stream into one action per press.
- **Shift+Tab still technically works as forward:** since Tab now ignores Shift, pressing Shift+Tab does a Shift-press (one back) then a Tab (one forward). It nets out oddly, but the gesture is no longer needed — documented here only so the behavior isn't surprising.
- **Shift events are passed through, not consumed:** the handler returns the event normally (`Unmanaged.passUnretained(event)`) rather than swallowing the Shift `flagsChanged`, to avoid disturbing the system's modifier-state tracking while the switcher is open.
