import AppKit
import TabSwitchCore

final class AppController: HotkeyTapDelegate {
    private let tap = HotkeyTap()
    private let source = AXWindowSource()
    private let panel = SwitcherPanel()
    private let mru = MRUList()
    private lazy var mruTracker = MRUTracker(mru: mru)

    private var state: SwitcherState?

    var isSessionOpen: Bool { state != nil }

    func start() {
        // AX calls are synchronous IPC run inside the event-tap callback. The
        // default timeout is 6s, and one busy app (Rider, Raycast seen at >1s)
        // stalls the keyboard and gets the tap disabled by the OS. Cap it
        // globally (system-wide element = default for all elements); a slow
        // app's windows just drop out of that one switcher open.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.2)
        mruTracker.start()
        tap.delegate = self
        tap.start()
        NSLog("tab-switch: controller started")
    }

    func hotkeyOpen(scope: Scope, reverse: Bool) {
        var t = CFAbsoluteTimeGetCurrent()  // DEBUG-LAG
        mruTracker.recordFrontmost()
        lagLog(String(format: "recordFrontmost %.1fms", (CFAbsoluteTimeGetCurrent() - t) * 1000)); t = CFAbsoluteTimeGetCurrent()
        let (all, activePID) = source.enumerate()
        lagLog(String(format: "enumerate %.1fms (%d windows)", (CFAbsoluteTimeGetCurrent() - t) * 1000, all.count)); t = CFAbsoluteTimeGetCurrent()
        mru.prune(validIDs: all.map(\.id))
        let scoped = scope.filter(all, activePID: activePID)
        let ordered = mru.order(scoped)
        guard !ordered.isEmpty else { return }

        let state = SwitcherState(windows: ordered)
        if reverse { state.prev() }
        self.state = state
        render(state)
        lagLog(String(format: "open render %.1fms", (CFAbsoluteTimeGetCurrent() - t) * 1000))  // DEBUG-LAG
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
        Focuser.focus(selected.id, using: source.elements)
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
    }
}

// DEBUG-LAG: NSLog args are redacted in the unified log, so append to a file.
func lagLog(_ msg: String) {
    let line = "\(Date().timeIntervalSince1970) \(msg)\n"
    guard let h = FileHandle(forWritingAtPath: "/tmp/tab-switch-lag.log") else {
        FileManager.default.createFile(atPath: "/tmp/tab-switch-lag.log", contents: line.data(using: .utf8)); return
    }
    h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile()
}
