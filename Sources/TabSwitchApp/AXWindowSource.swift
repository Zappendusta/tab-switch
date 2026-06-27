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
