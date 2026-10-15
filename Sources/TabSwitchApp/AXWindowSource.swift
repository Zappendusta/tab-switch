import AppKit
import ApplicationServices
import TabSwitchCore

final class AXWindowSource {
    /// Running-app fields the enumeration needs. Captured on the main thread,
    /// since NSRunningApplication is main-thread state.
    struct App {
        let pid: pid_t
        let name: String
        let bundleID: String
        let isRegular: Bool
        let isAccessory: Bool
    }

    static func snapshotApps() -> [App] {
        NSWorkspace.shared.runningApplications.map {
            App(pid: $0.processIdentifier, name: $0.localizedName ?? "", bundleID: $0.bundleIdentifier ?? "",
                isRegular: $0.activationPolicy == .regular, isAccessory: $0.activationPolicy == .accessory)
        }
    }

    /// Returns all standard, titled windows of `running` apps, plus the live
    /// `WindowID → AXUIElement` map that `Focuser` needs. Slow (AX IPC, up to
    /// the messaging timeout per app): call off the main thread.
    func enumerate(_ running: [App]) -> (windows: [WindowInfo], elements: [WindowID: AXUIElement]) {
        var elements: [WindowID: AXUIElement] = [:]
        var result: [WindowInfo] = []

        // Some apps (Steam/CEF) host their real windows in an .accessory helper
        // process. Include accessory apps only when CGWindowList says they own a
        // layer-0 window — AX-querying all ~60 accessory apps costs ~800ms.
        let windowOwnerPIDs: Set<pid_t> = {
            let info = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
            return Set(info.compactMap { w -> pid_t? in
                guard (w[kCGWindowLayer as String] as? Int) == 0,
                      let pid = w[kCGWindowOwnerPID as String] as? Int else { return nil }
                return pid_t(pid)
            })
        }()

        let appInfo = running.filter { $0.isRegular || ($0.isAccessory && windowOwnerPIDs.contains($0.pid)) }

        // AX queries are synchronous IPC, one round-trip per app. Running them
        // concurrently makes open cost ~ the slowest app instead of the sum.
        var perApp = [[(WindowInfo, AXUIElement)]](repeating: [], count: appInfo.count)
        perApp.withUnsafeMutableBufferPointer { slots in
            DispatchQueue.concurrentPerform(iterations: appInfo.count) { i in
                slots[i] = windows(of: appInfo[i])  // each iteration writes only its own slot
            }
        }

        for (info, axWindow) in perApp.joined() {
            elements[info.id] = axWindow
            result.append(info)
        }
        return (result, elements)
    }

    private func windows(of app: App) -> [(WindowInfo, AXUIElement)] {
        let appElement = AXUIElementCreateApplication(app.pid)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let axWindows = value as? [AXUIElement] else { return [] }

        var found: [(WindowInfo, AXUIElement)] = []
        for axWindow in axWindows {
            guard isStandardWindow(axWindow) else { continue }
            let title = stringAttribute(axWindow, kAXTitleAttribute) ?? ""
            if title.isEmpty { continue }  // skip titleless utility windows
            let minimized = boolAttribute(axWindow, kAXMinimizedAttribute) ?? false

            // Stable CGWindowID as the identity. Skip windows we can't id.
            var cgID = CGWindowID(0)
            guard _AXUIElementGetWindow(axWindow, &cgID) == .success, cgID != 0 else { continue }
            found.append((WindowInfo(
                id: WindowID(String(cgID)),
                pid: app.pid,
                appName: app.name,
                appBundleID: app.bundleID,
                title: title,
                isMinimized: minimized
            ), axWindow))
        }
        return found
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
