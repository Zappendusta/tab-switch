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
            let t = CFAbsoluteTimeGetCurrent()  // DEBUG-LAG
            self?.handleActivation(note)
            lagLog(String(format: "didActivate record %.1fms", (CFAbsoluteTimeGetCurrent() - t) * 1000))  // DEBUG-LAG
        }
    }

    private func handleActivation(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        record(focusedWindowOf: app)
    }

    /// Record the frontmost app's focused window. Called at switcher open:
    /// didActivateApplication fires before a launching app has a window, and
    /// never fires for Cmd+N / Cmd+` inside the active app, so the MRU can be
    /// stale exactly when it matters.
    func recordFrontmost() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        record(focusedWindowOf: app)
    }

    private func record(focusedWindowOf app: NSRunningApplication) {
        // Accessory apps included too: Steam/CEF helpers own real windows
        // (see AXWindowSource). AX checks below gate out junk.
        guard app.activationPolicy != .prohibited else { return }

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
