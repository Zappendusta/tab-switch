import AppKit
import TabSwitchCore

final class AppController: HotkeyTapDelegate {
    private let tap = HotkeyTap()
    private let source = AXWindowSource()
    private let panel = SwitcherPanel()
    private let mru = MRUList()
    private lazy var mruTracker = MRUTracker(mru: mru)

    private var state: SwitcherState?

    /// Open-session context; nil when no switcher is open.
    private var session: (scope: Scope, activePID: Int32)?

    /// Window list kept current in the background so opening never waits on AX.
    private var windows: [WindowInfo] = []
    private var elements: [WindowID: AXUIElement] = [:]
    private let refreshQueue = DispatchQueue(label: "tab-switch.window-refresh", qos: .userInitiated)
    private var refreshing = false
    private var refreshTimer: Timer?

    func start() {
        // AX calls are synchronous IPC. The default timeout is 6s, and one busy
        // app (Rider, Raycast seen at >1s) stalls the whole refresh. Cap it
        // globally (system-wide element = default for all elements); a slow
        // app's windows just drop out of that one refresh.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.2)
        mruTracker.start()
        refresh()
        // shortcut: polls every 1s; switch to AX/NSWorkspace observers if the idle CPU cost matters.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        tap.delegate = self
        tap.start()
        NSLog("tab-switch: controller started")
    }

    /// Re-enumerate windows off the main thread; at most one refresh in flight.
    private func refresh() {
        guard !refreshing else { return }
        refreshing = true
        let apps = AXWindowSource.snapshotApps()
        refreshQueue.async { [source] in
            let t = CFAbsoluteTimeGetCurrent()  // DEBUG-LAG
            let (windows, elements) = source.enumerate(apps)
            let ms = (CFAbsoluteTimeGetCurrent() - t) * 1000
            if ms > 300 { lagLog(String(format: "enumerate %.1fms (%d windows)", ms, windows.count)) }  // DEBUG-LAG
            DispatchQueue.main.async { self.apply(windows, elements) }
        }
    }

    private func apply(_ fresh: [WindowInfo], _ freshElements: [WindowID: AXUIElement]) {
        refreshing = false
        elements = freshElements
        guard fresh != windows else { return }
        windows = fresh
        mru.prune(validIDs: fresh.map(\.id))
        if session != nil { rebuildState(reverse: false) }
    }

    func hotkeyOpen(scope: Scope, reverse: Bool) {
        var t = CFAbsoluteTimeGetCurrent()  // DEBUG-LAG
        var steps: [String] = []  // DEBUG-LAG
        func lap(_ name: String) {  // DEBUG-LAG
            let now = CFAbsoluteTimeGetCurrent()
            steps.append(String(format: "%@ %.1f", name, (now - t) * 1000)); t = now
        }
        let t0 = t  // DEBUG-LAG
        mruTracker.recordFrontmost()
        lap("frontmostWindow")
        session = (scope, NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1)
        lap("frontmostApp")
        rebuildState(reverse: reverse)
        lap("state+render")
        // Cached list may miss a just-opened window; a fresh one re-renders in place.
        // After rebuildState: the panel is already drawn (SwitcherPanel.show flushes).
        refresh()
        lap("refresh")
        lagLog(String(format: "open %.1fms [%@]", (CFAbsoluteTimeGetCurrent() - t0) * 1000, steps.joined(separator: ", ")))  // DEBUG-LAG
    }

    /// Build the session's state from the cached list, keeping the current
    /// selection when the list is refreshed mid-session.
    private func rebuildState(reverse: Bool) {
        guard let session else { return }
        let ordered = mru.order(session.scope.filter(windows, activePID: session.activePID))
        guard !ordered.isEmpty else {
            state = nil
            panel.hide()
            return
        }
        let state = SwitcherState(windows: ordered)
        if let previous = self.state?.selected?.id {
            state.select(previous)
        } else if reverse {
            state.prev()
        }
        self.state = state
        render(state)
    }

    func hotkeyNext() {
        guard let state else { return }
        state.next()
        render(state)
    }

    func hotkeyPrev() {
        guard let state else { return }
        state.prev()
        render(state)
    }

    func hotkeyCommit() {
        defer { endSession() }
        guard let state, let selected = state.selected else { return }
        let t = CFAbsoluteTimeGetCurrent()  // DEBUG-LAG
        Focuser.focus(selected.id, using: elements)
        lagLog(String(format: "focus %.1fms", (CFAbsoluteTimeGetCurrent() - t) * 1000))  // DEBUG-LAG
        mru.recordFocus(selected.id)
    }

    func hotkeyCancel() {
        endSession()
    }

    private func render(_ state: SwitcherState) {
        let t = CFAbsoluteTimeGetCurrent()  // DEBUG-LAG
        panel.show(windows: state.windows, selectedIndex: state.selectedIndex)
        lagLog(String(format: "render %.1fms", (CFAbsoluteTimeGetCurrent() - t) * 1000))  // DEBUG-LAG
    }

    private func endSession() {
        let t = CFAbsoluteTimeGetCurrent()  // DEBUG-LAG
        panel.hide()
        lagLog(String(format: "hide %.1fms", (CFAbsoluteTimeGetCurrent() - t) * 1000))  // DEBUG-LAG
        state = nil
        session = nil
    }
}

/// Off by default: each write costs ~2-4ms (30-100ms spikes) on the calling thread.
/// Enable: `defaults write local.tabswitch lagLog -bool true`, then restart the app.
private let lagLogEnabled = UserDefaults.standard.bool(forKey: "lagLog")

// DEBUG-LAG: NSLog args are redacted in the unified log, so append to a file.
func lagLog(_ msg: @autoclosure () -> String) {
    guard lagLogEnabled else { return }
    let msg = msg()
    let line = "\(Date().timeIntervalSince1970) \(msg)\n"
    guard let h = FileHandle(forWritingAtPath: "/tmp/tab-switch-lag.log") else {
        FileManager.default.createFile(atPath: "/tmp/tab-switch-lag.log", contents: line.data(using: .utf8)); return
    }
    h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile()
}
