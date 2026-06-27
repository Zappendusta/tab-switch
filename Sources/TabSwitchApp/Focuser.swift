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
