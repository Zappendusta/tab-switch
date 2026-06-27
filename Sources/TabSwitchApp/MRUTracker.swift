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
