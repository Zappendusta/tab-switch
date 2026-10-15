import AppKit
import ApplicationServices
import TabSwitchCore

final class MRUTracker {
    private let mru: MRUList
    private var observer: NSObjectProtocol?
    /// Serial, so activations are recorded in the order they happened.
    private let queue = DispatchQueue(label: "tab-switch.mru", qos: .userInitiated)

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
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.activationPolicy != .prohibited else { return }
        // AX IPC off main: a slow app (162ms seen) must not delay the next switcher open.
        let pid = app.processIdentifier
        queue.async { [mru] in
            guard let id = Self.focusedWindow(of: pid, timeout: 0.2) else { return }
            DispatchQueue.main.async { mru.recordFocus(id) }
        }
    }

    /// Record the frontmost app's focused window. Called at switcher open:
    /// didActivateApplication fires before a launching app has a window, and
    /// never fires for Cmd+N / Cmd+` inside the active app, so the MRU can be
    /// stale exactly when it matters.
    func recordFrontmost() {
        // Accessory apps included too: Steam/CEF helpers own real windows
        // (see AXWindowSource). AX checks below gate out junk.
        guard let app = NSWorkspace.shared.frontmostApplication, app.activationPolicy != .prohibited else { return }
        // Runs on main at open, so cap it tight: healthy apps answer in ~1ms; a
        // slow one falls back to the MRU order kept by activation tracking.
        if let id = Self.focusedWindow(of: app.processIdentifier, timeout: 0.05) { mru.recordFocus(id) }
    }

    private static func focusedWindow(of pid: pid_t, timeout: Float) -> WindowID? {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, timeout)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focused) == .success,
              let focusedRef = focused,
              CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else { return nil }

        let window = focusedRef as! AXUIElement
        var cgID = CGWindowID(0)
        guard _AXUIElementGetWindow(window, &cgID) == .success, cgID != 0 else { return nil }
        return WindowID(String(cgID))
    }
}
