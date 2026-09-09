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
        mruTracker.start()
        tap.delegate = self
        tap.start()
        NSLog("tab-switch: controller started")
    }

    func hotkeyOpen(scope: Scope, reverse: Bool) {
        mruTracker.recordFrontmost()
        let (all, activePID) = source.enumerate()
        mru.prune(validIDs: all.map(\.id))
        let scoped = scope.filter(all, activePID: activePID)
        let ordered = mru.order(scoped)
        guard !ordered.isEmpty else { return }

        let state = SwitcherState(windows: ordered)
        if reverse { state.prev() }
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
        Focuser.focus(selected.id, using: source.elements)
        mru.recordFocus(selected.id)
    }

    func hotkeyCancel() {
        endSession()
    }

    private func render(_ state: SwitcherState) {
        panel.show(windows: state.windows, selectedIndex: state.selectedIndex)
    }

    private func endSession() {
        panel.hide()
        state = nil
    }
}
