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
