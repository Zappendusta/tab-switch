# tab-switch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS background app where Option+Tab switches windows of the current app and Cmd+Tab switches windows of all apps, each via an MRU-ordered text-list overlay.

**Architecture:** A Swift Package with two targets. `TabSwitchCore` (library) holds all pure, unit-tested logic: MRU ordering, selection cycling, and scope filtering, operating on plain `WindowInfo` values. `TabSwitchApp` (executable) is the thin, manually-verified macOS layer: a `CGEventTap` for hotkeys, the Accessibility API for enumerating/focusing windows, and a non-activating `NSPanel` overlay. A bundling script wraps the executable into a `tab-switch.app` (LSUIElement) so the Accessibility permission attaches to a stable bundle.

**Tech Stack:** Swift 5.9+, Swift Package Manager, AppKit, ApplicationServices (Accessibility/AX), CoreGraphics (CGEventTap), XCTest. macOS 13+.

---

## File Structure

```
Package.swift                                  # SwiftPM manifest, 2 targets + test target
Sources/
  TabSwitchCore/                               # pure logic, fully unit-tested
    WindowInfo.swift                           # value type describing a window
    Scope.swift                                # enum + filtering (all-apps vs active-app)
    MRUList.swift                              # most-recently-used ordering of window ids
    SwitcherState.swift                        # selection index, next/prev/wrap, commit
  TabSwitchApp/                                 # macOS system layer, manually verified
    main.swift                                 # entry point, builds AppController, runs NSApp
    AppController.swift                         # wires tap → state → panel → focuser
    Permissions.swift                          # Accessibility trust check + prompt
    AXPrivate.swift                            # private _AXUIElementGetWindow → stable CGWindowID
    AXWindowSource.swift                        # AX enumeration → [WindowInfo] + id→AXUIElement map
    MRUTracker.swift                           # observes app activation → records focus into MRUList
    Focuser.swift                              # raise/activate a window by id
    SwitcherPanel.swift                         # non-activating NSPanel text-list overlay
    HotkeyTap.swift                            # CGEventTap: detect/consume Cmd/Opt+Tab
Tests/
  TabSwitchCoreTests/
    ScopeTests.swift
    MRUListTests.swift
    SwitcherStateTests.swift
scripts/
  make-app.sh                                  # bundle the executable into tab-switch.app
```

Files that change together live together. The Core/App split is the key boundary: Core never imports AppKit or AX, so it runs under `swift test` with no permissions and no UI.

---

## Task 1: Project scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/TabSwitchCore/Placeholder.swift`
- Create: `Sources/TabSwitchApp/main.swift`
- Create: `Tests/TabSwitchCoreTests/ScaffoldTests.swift`

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "tab-switch",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "TabSwitchCore"),
        .executableTarget(
            name: "TabSwitchApp",
            dependencies: ["TabSwitchCore"]
        ),
        .testTarget(
            name: "TabSwitchCoreTests",
            dependencies: ["TabSwitchCore"]
        ),
    ]
)
```

- [ ] **Step 2: Add a temporary placeholder so Core compiles**

Create `Sources/TabSwitchCore/Placeholder.swift`:

```swift
// Temporary; deleted in Task 2.
enum Placeholder {}
```

- [ ] **Step 3: Add a minimal executable entry**

Create `Sources/TabSwitchApp/main.swift`:

```swift
print("tab-switch starting")
```

- [ ] **Step 4: Write a scaffold test**

Create `Tests/TabSwitchCoreTests/ScaffoldTests.swift`:

```swift
import XCTest
@testable import TabSwitchCore

final class ScaffoldTests: XCTestCase {
    func testScaffoldCompiles() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 5: Build and test**

Run: `swift build && swift test`
Expected: build succeeds; 1 test passes.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "chore: scaffold SwiftPM project with Core/App targets"
```

---

## Task 2: WindowInfo + Scope

**Files:**
- Create: `Sources/TabSwitchCore/WindowInfo.swift`
- Create: `Sources/TabSwitchCore/Scope.swift`
- Delete: `Sources/TabSwitchCore/Placeholder.swift`
- Test: `Tests/TabSwitchCoreTests/ScopeTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/TabSwitchCoreTests/ScopeTests.swift`:

```swift
import XCTest
@testable import TabSwitchCore

final class ScopeTests: XCTestCase {
    private func win(_ id: String, pid: Int32) -> WindowInfo {
        WindowInfo(id: WindowID(id), pid: pid, appName: "App", appBundleID: "com.app", title: id, isMinimized: false)
    }

    func testAllAppsKeepsEverything() {
        let windows = [win("a", pid: 1), win("b", pid: 2)]
        let result = Scope.allApps.filter(windows, activePID: 1)
        XCTAssertEqual(result.map(\.id), [WindowID("a"), WindowID("b")])
    }

    func testActiveAppKeepsOnlyActivePID() {
        let windows = [win("a", pid: 1), win("b", pid: 2), win("c", pid: 1)]
        let result = Scope.activeApp.filter(windows, activePID: 1)
        XCTAssertEqual(result.map(\.id), [WindowID("a"), WindowID("c")])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ScopeTests`
Expected: FAIL — `WindowInfo` / `WindowID` / `Scope` not defined.

- [ ] **Step 3: Implement WindowInfo**

Delete `Sources/TabSwitchCore/Placeholder.swift`. Create `Sources/TabSwitchCore/WindowInfo.swift`:

```swift
import Foundation

/// Stable-within-a-session identifier for a window.
public struct WindowID: Hashable, Equatable {
    public let raw: String
    public init(_ raw: String) { self.raw = raw }
}

/// Plain value describing a window. No AppKit/AX types so Core stays testable.
public struct WindowInfo: Equatable {
    public let id: WindowID
    public let pid: Int32
    public let appName: String
    public let appBundleID: String
    public let title: String
    public let isMinimized: Bool

    public init(id: WindowID, pid: Int32, appName: String, appBundleID: String, title: String, isMinimized: Bool) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.appBundleID = appBundleID
        self.title = title
        self.isMinimized = isMinimized
    }
}
```

- [ ] **Step 4: Implement Scope**

Create `Sources/TabSwitchCore/Scope.swift`:

```swift
public enum Scope {
    case allApps
    case activeApp

    /// Returns the windows relevant to this scope, preserving input order.
    public func filter(_ windows: [WindowInfo], activePID: Int32) -> [WindowInfo] {
        switch self {
        case .allApps:
            return windows
        case .activeApp:
            return windows.filter { $0.pid == activePID }
        }
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter ScopeTests`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/TabSwitchCore Tests/TabSwitchCoreTests/ScopeTests.swift
git rm Sources/TabSwitchCore/Placeholder.swift 2>/dev/null; git add -A
git commit -m "feat(core): add WindowInfo value type and Scope filtering"
```

---

## Task 3: MRUList

**Files:**
- Create: `Sources/TabSwitchCore/MRUList.swift`
- Test: `Tests/TabSwitchCoreTests/MRUListTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/TabSwitchCoreTests/MRUListTests.swift`:

```swift
import XCTest
@testable import TabSwitchCore

final class MRUListTests: XCTestCase {
    private func win(_ id: String) -> WindowInfo {
        WindowInfo(id: WindowID(id), pid: 1, appName: "App", appBundleID: "com.app", title: id, isMinimized: false)
    }

    func testUnknownWindowsKeepInputOrderStably() {
        let mru = MRUList()
        let ordered = mru.order([win("a"), win("b"), win("c")])
        XCTAssertEqual(ordered.map(\.id.raw), ["a", "b", "c"])
    }

    func testRecordFocusMovesToFront() {
        let mru = MRUList()
        mru.recordFocus(WindowID("c"))
        mru.recordFocus(WindowID("a"))
        // MRU order is now: a (most recent), c, then unknowns in input order.
        let ordered = mru.order([win("a"), win("b"), win("c")])
        XCTAssertEqual(ordered.map(\.id.raw), ["a", "c", "b"])
    }

    func testPruneRemovesStaleIDs() {
        let mru = MRUList()
        mru.recordFocus(WindowID("x"))
        mru.recordFocus(WindowID("a"))
        mru.prune(validIDs: [WindowID("a")])
        let ordered = mru.order([win("a"), win("b")])
        // "x" is gone; "a" is most recent, "b" unknown follows.
        XCTAssertEqual(ordered.map(\.id.raw), ["a", "b"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MRUListTests`
Expected: FAIL — `MRUList` not defined.

- [ ] **Step 3: Implement MRUList**

Create `Sources/TabSwitchCore/MRUList.swift`:

```swift
/// Tracks most-recently-used order of window ids. Front = most recent.
public final class MRUList {
    private var order_: [WindowID] = []

    public init() {}

    /// Move `id` to the front (most recent).
    public func recordFocus(_ id: WindowID) {
        order_.removeAll { $0 == id }
        order_.insert(id, at: 0)
    }

    /// Drop any tracked ids not in `validIDs`.
    public func prune(validIDs: [WindowID]) {
        let valid = Set(validIDs)
        order_.removeAll { !valid.contains($0) }
    }

    /// Sort `windows` by MRU position. Windows we haven't seen keep their
    /// relative input order and come after all known windows.
    public func order(_ windows: [WindowInfo]) -> [WindowInfo] {
        let rank = Dictionary(uniqueKeysWithValues: order_.enumerated().map { ($1, $0) })
        return windows.enumerated().sorted { lhs, rhs in
            let lr = rank[lhs.element.id]
            let rr = rank[rhs.element.id]
            switch (lr, rr) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return lhs.offset < rhs.offset  // stable
            }
        }.map(\.element)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MRUListTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/TabSwitchCore/MRUList.swift Tests/TabSwitchCoreTests/MRUListTests.swift
git commit -m "feat(core): add MRUList ordering with prune"
```

---

## Task 4: SwitcherState

**Files:**
- Create: `Sources/TabSwitchCore/SwitcherState.swift`
- Test: `Tests/TabSwitchCoreTests/SwitcherStateTests.swift`

The state machine for one switch session: holds the ordered window list, the selected index, and handles next/prev with wrap-around. Initial selection is index 1 (the previous window) when there are 2+ windows, so Tab-once-and-release returns to the previous window.

- [ ] **Step 1: Write the failing test**

Create `Tests/TabSwitchCoreTests/SwitcherStateTests.swift`:

```swift
import XCTest
@testable import TabSwitchCore

final class SwitcherStateTests: XCTestCase {
    private func wins(_ ids: [String]) -> [WindowInfo] {
        ids.map { WindowInfo(id: WindowID($0), pid: 1, appName: "App", appBundleID: "com.app", title: $0, isMinimized: false) }
    }

    func testInitialSelectionIsPreviousWindow() {
        let state = SwitcherState(windows: wins(["a", "b", "c"]))
        XCTAssertEqual(state.selectedIndex, 1)
        XCTAssertEqual(state.selected?.id.raw, "b")
    }

    func testSingleWindowSelectsItself() {
        let state = SwitcherState(windows: wins(["a"]))
        XCTAssertEqual(state.selectedIndex, 0)
        XCTAssertEqual(state.selected?.id.raw, "a")
    }

    func testEmptyHasNoSelection() {
        let state = SwitcherState(windows: wins([]))
        XCTAssertNil(state.selected)
    }

    func testNextWrapsAround() {
        let state = SwitcherState(windows: wins(["a", "b", "c"]))  // starts at index 1
        state.next()  // -> 2
        XCTAssertEqual(state.selected?.id.raw, "c")
        state.next()  // wrap -> 0
        XCTAssertEqual(state.selected?.id.raw, "a")
    }

    func testPrevWrapsAround() {
        let state = SwitcherState(windows: wins(["a", "b", "c"]))  // starts at index 1
        state.prev()  // -> 0
        XCTAssertEqual(state.selected?.id.raw, "a")
        state.prev()  // wrap -> 2
        XCTAssertEqual(state.selected?.id.raw, "c")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SwitcherStateTests`
Expected: FAIL — `SwitcherState` not defined.

- [ ] **Step 3: Implement SwitcherState**

Create `Sources/TabSwitchCore/SwitcherState.swift`:

```swift
/// State for a single switch session.
public final class SwitcherState {
    public let windows: [WindowInfo]
    public private(set) var selectedIndex: Int

    public init(windows: [WindowInfo]) {
        self.windows = windows
        // Pre-select the previous window (index 1) when there are 2+ windows.
        self.selectedIndex = windows.count >= 2 ? 1 : 0
    }

    public var selected: WindowInfo? {
        guard windows.indices.contains(selectedIndex) else { return nil }
        return windows[selectedIndex]
    }

    public func next() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
    }

    public func prev() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SwitcherStateTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/TabSwitchCore/SwitcherState.swift Tests/TabSwitchCoreTests/SwitcherStateTests.swift
git commit -m "feat(core): add SwitcherState selection cycling"
```

---

## Task 5: App bundle + permissions

From here on, tasks touch macOS system APIs that can't be unit-tested. Each has a **build + manual verification** step instead of an automated test.

**Files:**
- Create: `scripts/make-app.sh`
- Create: `Sources/TabSwitchApp/Permissions.swift`
- Modify: `Sources/TabSwitchApp/main.swift`

- [ ] **Step 1: Write the bundling script**

Create `scripts/make-app.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-debug}"
APP="tab-switch.app"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"

swift build -c "$CONFIG"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_PATH/TabSwitchApp" "$APP/Contents/MacOS/tab-switch"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>tab-switch</string>
  <key>CFBundleIdentifier</key><string>local.tabswitch</string>
  <key>CFBundleExecutable</key><string>tab-switch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

echo "Built $APP"
```

Make it executable:

```bash
chmod +x scripts/make-app.sh
```

- [ ] **Step 2: Implement the permissions check**

Create `Sources/TabSwitchApp/Permissions.swift`:

```swift
import AppKit
import ApplicationServices

enum Permissions {
    /// True if this process is trusted for Accessibility (required for both
    /// the event tap and AX window control).
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user (system dialog) and opens the Accessibility pane.
    static func requestTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 3: Wire a minimal app that checks permission**

Replace `Sources/TabSwitchApp/main.swift`:

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // agent app, no Dock icon

if Permissions.isTrusted() {
    NSLog("tab-switch: Accessibility granted")
} else {
    NSLog("tab-switch: Accessibility NOT granted, prompting")
    Permissions.requestTrust()
}

app.run()
```

- [ ] **Step 4: Build the bundle and verify the permission flow**

Run:

```bash
./scripts/make-app.sh debug
open tab-switch.app
```

Expected (first run): macOS shows an Accessibility prompt and opens System Settings → Privacy & Security → Accessibility. Add/enable `tab-switch`. Check Console.app for "Accessibility granted" on the next `open tab-switch.app`.

To quit the running agent during development: `pkill -f tab-switch || true`

- [ ] **Step 5: Commit**

```bash
git add scripts/make-app.sh Sources/TabSwitchApp/Permissions.swift Sources/TabSwitchApp/main.swift
git commit -m "feat(app): bundle as LSUIElement app with Accessibility check"
```

---

## Task 6: AXWindowSource

**Files:**
- Create: `Sources/TabSwitchApp/AXPrivate.swift`
- Create: `Sources/TabSwitchApp/AXWindowSource.swift`
- Modify: `Sources/TabSwitchApp/main.swift`

Enumerates on-screen app windows via the Accessibility API into `[WindowInfo]`, and keeps a `WindowID → AXUIElement` map (rebuilt each enumeration) so the Focuser can act on a selection by id. The `WindowID` is the window's **stable `CGWindowID`** obtained from the private `_AXUIElementGetWindow`, so the same window keeps the same id across enumerations — this is what makes MRU work across switch sessions.

- [ ] **Step 1: Declare the private CGWindowID accessor**

Create `Sources/TabSwitchApp/AXPrivate.swift`:

```swift
import ApplicationServices
import CoreGraphics

// Private but long-stable API (used by AltTab and others) to get a window's
// CGWindowID from its AXUIElement. Gives us a stable per-window identifier.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError
```

- [ ] **Step 2: Implement AXWindowSource**

Create `Sources/TabSwitchApp/AXWindowSource.swift`:

```swift
import AppKit
import ApplicationServices
import TabSwitchCore

final class AXWindowSource {
    /// Live map from the ids returned by `enumerate()` to AX elements.
    private(set) var elements: [WindowID: AXUIElement] = [:]

    /// Returns all standard, titled windows of regular apps, plus the pid of
    /// the frontmost regular app at call time.
    func enumerate() -> (windows: [WindowInfo], activePID: Int32) {
        elements.removeAll()
        var result: [WindowInfo] = []

        let activePID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1

        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }

        for app in apps {
            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)

            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
                  let axWindows = value as? [AXUIElement] else { continue }

            for axWindow in axWindows {
                guard isStandardWindow(axWindow) else { continue }
                let title = stringAttribute(axWindow, kAXTitleAttribute) ?? ""
                if title.isEmpty { continue }  // skip titleless utility windows
                let minimized = boolAttribute(axWindow, kAXMinimizedAttribute) ?? false

                // Stable CGWindowID as the identity. Skip windows we can't id.
                var cgID = CGWindowID(0)
                guard _AXUIElementGetWindow(axWindow, &cgID) == .success, cgID != 0 else { continue }
                let id = WindowID(String(cgID))
                elements[id] = axWindow
                result.append(WindowInfo(
                    id: id,
                    pid: pid,
                    appName: app.localizedName ?? "",
                    appBundleID: app.bundleIdentifier ?? "",
                    title: title,
                    isMinimized: minimized
                ))
            }
        }
        return (result, activePID)
    }

    private func isStandardWindow(_ element: AXUIElement) -> Bool {
        guard let role = stringAttribute(element, kAXRoleAttribute) else { return false }
        guard role == (kAXWindowRole as String) else { return false }
        // Only standard windows (exclude sheets, drawers, etc.) when subrole present.
        if let subrole = stringAttribute(element, kAXSubroleAttribute) {
            return subrole == (kAXStandardWindowSubrole as String)
        }
        return true
    }

    private func stringAttribute(_ element: AXUIElement, _ attr: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func boolAttribute(_ element: AXUIElement, _ attr: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success else { return nil }
        return (value as? Bool)
    }
}
```

- [ ] **Step 3: Temporarily log enumeration on launch to verify**

Replace the body of `Sources/TabSwitchApp/main.swift` after `app.setActivationPolicy(.accessory)` and the permission block with this temporary verification (keep the permission block above it):

```swift
let source = AXWindowSource()
let (windows, activePID) = source.enumerate()
NSLog("tab-switch: activePID=\(activePID), windows=\(windows.count)")
for w in windows {
    NSLog("  [\(w.appName)] \(w.title) min=\(w.isMinimized) pid=\(w.pid)")
}

app.run()
```

- [ ] **Step 4: Build and verify enumeration**

Run:

```bash
pkill -f tab-switch || true
./scripts/make-app.sh debug
open tab-switch.app
```

Open a few apps with multiple windows first. In Console.app, filter for "tab-switch" and confirm it logs the open windows with sensible app names and titles, and a plausible `activePID`.

- [ ] **Step 5: Commit**

```bash
git add Sources/TabSwitchApp/AXPrivate.swift Sources/TabSwitchApp/AXWindowSource.swift Sources/TabSwitchApp/main.swift
git commit -m "feat(app): enumerate windows via Accessibility API with stable ids"
```

---

## Task 7: Focuser

**Files:**
- Create: `Sources/TabSwitchApp/Focuser.swift`

Raises and activates a chosen window by `WindowID`, using the AX element map from `AXWindowSource`. Un-minimizes first if needed, validates the element still exists, and activates the owning app so the window comes forward.

- [ ] **Step 1: Implement Focuser**

Create `Sources/TabSwitchApp/Focuser.swift`:

```swift
import AppKit
import ApplicationServices
import TabSwitchCore

enum Focuser {
    /// Focus the window identified by `id`. Returns true on success.
    @discardableResult
    static func focus(_ id: WindowID, using elements: [WindowID: AXUIElement]) -> Bool {
        guard let window = elements[id] else { return false }

        // Validate the element still exists by reading any attribute.
        var probe: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &probe) == .success else {
            return false
        }

        // Un-minimize if needed.
        var minimized: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
           (minimized as? Bool) == true {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }

        // Raise the window and make it main/focused.
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)

        // Activate the owning app so the window comes to the foreground.
        var pidValue: pid_t = 0
        if AXUIElementGetPid(window, &pidValue) == .success,
           let app = NSRunningApplication(processIdentifier: pidValue) {
            app.activate(options: [])
        }
        return true
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `swift build`
Expected: build succeeds. (Behavioral verification happens in Task 11 once the tap drives it.)

- [ ] **Step 3: Commit**

```bash
git add Sources/TabSwitchApp/Focuser.swift
git commit -m "feat(app): add Focuser to raise/activate a window by id"
```

---

## Task 8: MRUTracker

**Files:**
- Create: `Sources/TabSwitchApp/MRUTracker.swift`

Keeps the shared `MRUList` current with real usage by observing `NSWorkspace.didActivateApplication`. On each app activation it reads that app's focused window, resolves its stable `CGWindowID`, and records it as most-recent. This makes "Tab-once returns to the previous window" correct even when you switched windows by clicking, not just through the switcher. (Within-app window focus changes that don't activate a different app are only recorded on switcher commit — an accepted minimal-tool limitation.)

- [ ] **Step 1: Implement MRUTracker**

Create `Sources/TabSwitchApp/MRUTracker.swift`:

```swift
import AppKit
import ApplicationServices
import TabSwitchCore

final class MRUTracker {
    private let mru: MRUList
    private var observer: NSObjectProtocol?

    init(mru: MRUList) { self.mru = mru }

    func start() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handleActivation(note)
        }
    }

    private func handleActivation(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.activationPolicy == .regular else { return }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focused) == .success,
              let focusedRef = focused,
              CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else { return }

        let window = focusedRef as! AXUIElement
        var cgID = CGWindowID(0)
        guard _AXUIElementGetWindow(window, &cgID) == .success, cgID != 0 else { return }
        mru.recordFocus(WindowID(String(cgID)))
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `swift build`
Expected: build succeeds. (Behavioral verification happens in Task 11.)

- [ ] **Step 3: Commit**

```bash
git add Sources/TabSwitchApp/MRUTracker.swift
git commit -m "feat(app): track MRU via app-activation observer"
```

---

## Task 9: SwitcherPanel

**Files:**
- Create: `Sources/TabSwitchApp/SwitcherPanel.swift`

A borderless, **non-activating** `NSPanel` showing one row per window (app icon + title), with the selected row highlighted. Non-activating is critical: it must not steal key focus, otherwise the "active app" computed for Option+Tab scope would become tab-switch itself.

- [ ] **Step 1: Implement SwitcherPanel**

Create `Sources/TabSwitchApp/SwitcherPanel.swift`:

```swift
import AppKit
import TabSwitchCore

final class SwitcherPanel {
    private var panel: NSPanel?

    /// Show the panel for `windows` with `selectedIndex` highlighted.
    /// Safe to call repeatedly to update the highlight.
    func show(windows: [WindowInfo], selectedIndex: Int) {
        let rowHeight: CGFloat = 28
        let width: CGFloat = 420
        let height = max(rowHeight, CGFloat(windows.count) * rowHeight) + 16

        let panel = self.panel ?? makePanel()
        self.panel = panel

        let content = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        content.layer?.cornerRadius = 10

        for (i, w) in windows.enumerated() {
            let y = height - 8 - CGFloat(i + 1) * rowHeight
            let row = NSView(frame: NSRect(x: 8, y: y, width: width - 16, height: rowHeight))
            row.wantsLayer = true
            if i == selectedIndex {
                row.layer?.backgroundColor = NSColor.selectedContentBackgroundColor.cgColor
                row.layer?.cornerRadius = 6
            }

            let icon = NSImageView(frame: NSRect(x: 6, y: 4, width: 20, height: 20))
            icon.image = NSRunningApplication(processIdentifier: w.pid)?.icon
            row.addSubview(icon)

            let label = NSTextField(labelWithString: "\(w.appName) — \(w.title)")
            label.frame = NSRect(x: 34, y: 4, width: width - 16 - 40, height: 20)
            label.lineBreakMode = .byTruncatingTail
            label.textColor = (i == selectedIndex) ? .selectedMenuItemTextColor : .labelColor
            row.addSubview(label)

            content.addSubview(row)
        }

        panel.setContentSize(NSSize(width: width, height: height))
        panel.contentView = content
        centerOnActiveScreen(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 100),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        return panel
    }

    private func centerOnActiveScreen(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        ))
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `swift build`
Expected: build succeeds. (Visual verification happens in Task 11.)

- [ ] **Step 3: Commit**

```bash
git add Sources/TabSwitchApp/SwitcherPanel.swift
git commit -m "feat(app): add non-activating text-list overlay panel"
```

---

## Task 10: HotkeyTap

**Files:**
- Create: `Sources/TabSwitchApp/HotkeyTap.swift`

A `CGEventTap` at session level that detects Cmd+Tab / Option+Tab (with Shift for reverse), Esc, and modifier release. It **consumes** the Cmd+Tab and Option+Tab key events (returns `nil`) so the system app switcher never fires. It re-enables itself if macOS disables the tap. It reports semantic events to a delegate.

- [ ] **Step 1: Implement HotkeyTap**

Create `Sources/TabSwitchApp/HotkeyTap.swift`:

```swift
import AppKit
import CoreGraphics
import TabSwitchCore

protocol HotkeyTapDelegate: AnyObject {
    func hotkeyOpen(scope: Scope, reverse: Bool)
    func hotkeyNext()
    func hotkeyPrev()
    func hotkeyCancel()
    func hotkeyCommit()
    /// Whether a switch session is currently open (drives commit on release).
    var isSessionOpen: Bool { get }
}

final class HotkeyTap {
    weak var delegate: HotkeyTapDelegate?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let tabKey: Int64 = 0x30      // Tab
    private let escKey: Int64 = 0x35      // Escape

    /// Creates and enables the tap. Requires Accessibility trust.
    func start() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                let me = Unmanaged<HotkeyTap>.fromOpaque(refcon!).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            NSLog("tab-switch: failed to create event tap (Accessibility?)")
            return
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable if the system disabled us.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard let delegate = delegate else { return Unmanaged.passUnretained(event) }
        let flags = event.flags
        let cmd = flags.contains(.maskCommand)
        let option = flags.contains(.maskAlternate)
        let shift = flags.contains(.maskShift)

        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            if keyCode == tabKey && (cmd || option) {
                if delegate.isSessionOpen {
                    shift ? delegate.hotkeyPrev() : delegate.hotkeyNext()
                } else {
                    let scope: Scope = cmd ? .allApps : .activeApp
                    delegate.hotkeyOpen(scope: scope, reverse: shift)
                }
                return nil  // consume: system switcher never sees Cmd/Opt+Tab
            }

            if keyCode == escKey && delegate.isSessionOpen {
                delegate.hotkeyCancel()
                return nil
            }
        }

        if type == .flagsChanged && delegate.isSessionOpen {
            // Commit when both Cmd and Option are released.
            if !cmd && !option {
                delegate.hotkeyCommit()
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `swift build`
Expected: build succeeds. (Behavioral verification happens in Task 11.)

- [ ] **Step 3: Commit**

```bash
git add Sources/TabSwitchApp/HotkeyTap.swift
git commit -m "feat(app): add CGEventTap that consumes Cmd/Option+Tab"
```

---

## Task 11: AppController wiring + full verification

**Files:**
- Create: `Sources/TabSwitchApp/AppController.swift`
- Modify: `Sources/TabSwitchApp/main.swift`

Ties the pieces together: on `open`, enumerate windows, apply scope, MRU-order, build `SwitcherState`, and show the panel after a short delay (flash-avoidance). On next/prev, update state + panel. On commit, focus the selection and record it in the MRU list. On cancel, just hide.

- [ ] **Step 1: Implement AppController**

Create `Sources/TabSwitchApp/AppController.swift`:

```swift
import AppKit
import TabSwitchCore

final class AppController: HotkeyTapDelegate {
    private let tap = HotkeyTap()
    private let source = AXWindowSource()
    private let panel = SwitcherPanel()
    private let mru = MRUList()
    private lazy var mruTracker = MRUTracker(mru: mru)

    private var state: SwitcherState?
    private var showWorkItem: DispatchWorkItem?
    private let showDelay: TimeInterval = 0.15

    var isSessionOpen: Bool { state != nil }

    func start() {
        mruTracker.start()
        tap.delegate = self
        tap.start()
        NSLog("tab-switch: controller started")
    }

    func hotkeyOpen(scope: Scope, reverse: Bool) {
        let (all, activePID) = source.enumerate()
        mru.prune(validIDs: all.map(\.id))
        let scoped = scope.filter(all, activePID: activePID)
        let ordered = mru.order(scoped)
        guard !ordered.isEmpty else { return }

        let state = SwitcherState(windows: ordered)
        if reverse { state.prev() }
        self.state = state

        // Flash-avoidance: only render the panel if the modifier is held a
        // moment. A quick tap+release commits before this fires.
        let work = DispatchWorkItem { [weak self] in
            guard let self, let s = self.state else { return }
            self.panel.show(windows: s.windows, selectedIndex: s.selectedIndex)
        }
        showWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + showDelay, execute: work)
    }

    func hotkeyNext() {
        guard let state else { return }
        state.next()
        renderImmediately(state)
    }

    func hotkeyPrev() {
        guard let state else { return }
        state.prev()
        renderImmediately(state)
    }

    func hotkeyCommit() {
        defer { endSession() }
        guard let state, let selected = state.selected else { return }
        Focuser.focus(selected.id, using: source.elements)
        mru.recordFocus(selected.id)
    }

    func hotkeyCancel() {
        endSession()
    }

    private func renderImmediately(_ state: SwitcherState) {
        showWorkItem?.cancel()  // second Tab → show now, skip the delay
        panel.show(windows: state.windows, selectedIndex: state.selectedIndex)
    }

    private func endSession() {
        showWorkItem?.cancel()
        showWorkItem = nil
        panel.hide()
        state = nil
    }
}
```

- [ ] **Step 2: Replace main.swift with the real entry point**

Replace `Sources/TabSwitchApp/main.swift` entirely:

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // agent app, no Dock icon

guard Permissions.isTrusted() else {
    NSLog("tab-switch: Accessibility NOT granted, prompting")
    Permissions.requestTrust()
    // Re-launch after granting permission.
    app.run()
    exit(0)
}

let controller = AppController()
controller.start()
app.run()
```

- [ ] **Step 3: Build the bundle**

Run:

```bash
pkill -f tab-switch || true
./scripts/make-app.sh debug
open tab-switch.app
```

If you changed the binary, macOS may require re-confirming Accessibility — toggle `tab-switch` off/on in System Settings → Privacy & Security → Accessibility, then `open tab-switch.app` again.

- [ ] **Step 4: Run the full manual verification checklist**

With several apps open (at least one app having 2+ windows), verify each:

- [ ] **Cmd+Tab** shows the overlay listing windows from **all** apps; the native app switcher does **not** appear.
- [ ] **Option+Tab** shows the overlay listing windows of the **current app only**.
- [ ] Holding the modifier and pressing **Tab** repeatedly moves the highlight down and **wraps** to the top.
- [ ] **Shift+Tab** moves the highlight up and wraps to the bottom.
- [ ] **Releasing** the modifier focuses the highlighted window.
- [ ] A quick **Cmd+Tab + immediate release** jumps to the previous window with **no visible overlay flash** (MRU + flash-avoidance).
- [ ] **Esc** while the overlay is open cancels with no focus change.
- [ ] Selecting a **minimized** window un-minimizes and focuses it.
- [ ] Repeating Cmd+Tab+release **toggles** between the two most-recent windows (MRU front-moves on commit).

If a step fails, use superpowers:systematic-debugging before patching.

- [ ] **Step 5: Commit**

```bash
git add Sources/TabSwitchApp/AppController.swift Sources/TabSwitchApp/main.swift
git commit -m "feat(app): wire controller, tap, panel, focuser into working switcher"
```

---

## Notes & known risks

- **Cmd+Tab interception:** A `.cgSessionEventTap` with `.headInsertEventTap` receives Cmd+Tab before the system app switcher in practice (this is how AltTab works). If the native switcher still flashes on some macOS builds, that's the place to investigate first.
- **Re-confirming Accessibility after rebuilds:** Because the dev binary isn't code-signed with a stable identity, macOS may drop the Accessibility grant when the binary changes. Toggling the entry off/on in System Settings fixes it. (Out of scope to solve permanently — this is a personal tool.)
- **AX enumeration performance:** With many apps open, `enumerate()` walks every regular app. If it feels laggy, the mitigation noted in the spec is to cache the list and refresh on `NSWorkspace.didActivateApplication`. Not implemented now (YAGNI).
- **MRU across app activations:** The current MRU only records windows focused *through* the switcher. That satisfies the "toggle between last two" behavior. Observing external focus changes (clicking windows directly) is a possible later refinement, deliberately omitted to stay minimal.
```
