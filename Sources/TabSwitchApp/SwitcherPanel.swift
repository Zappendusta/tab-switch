import AppKit
import TabSwitchCore

final class SwitcherPanel {
    private typealias Row = (row: NSView, icon: NSImageView, label: NSTextField)

    /// One panel per screen, so the switcher is visible wherever the user is looking.
    /// Panels stay ordered in at alpha 0 between sessions: showing is then an
    /// alpha change, not a window-server order-in on every screen.
    private var panels: [NSPanel] = []
    /// Row views per panel, kept so Tab only moves the highlight instead of rebuilding every screen's views.
    private var rows: [[Row]] = []
    private var shownWindows: [WindowInfo] = []
    private var isShown = false
    /// App icons by pid: NSRunningApplication.icon is slow to fetch on every open.
    private var iconCache: [pid_t: NSImage] = [:]

    private let rowHeight: CGFloat = 28
    private let width: CGFloat = 420

    /// Show the panel for `windows` with `selectedIndex` highlighted.
    /// Safe to call repeatedly to update the highlight.
    func show(windows: [WindowInfo], selectedIndex: Int) {
        let screens = Self.targetScreens()
        if windows != shownWindows || rows.count != screens.count {
            update(windows: windows, screens: screens)
        }
        rows.forEach { highlight($0, selectedIndex: selectedIndex) }
        if !isShown {
            for (panel, screen) in zip(panels, screens) {
                center(panel, on: screen)
                panel.alphaValue = 1
                panel.displayIfNeeded()
            }
            // Push to the window server now, so the panel is on screen before the
            // caller does further main-thread work (e.g. the open-time refresh).
            CATransaction.flush()
            isShown = true
        }
    }

    func hide() {
        panels.forEach { $0.alphaValue = 0 }
        isShown = false
    }

    /// Put `windows` into every screen's panel. Same row count: refill the
    /// existing rows in place. Otherwise rebuild the content views.
    private func update(windows: [WindowInfo], screens: [NSScreen]) {
        while panels.count < screens.count {
            let panel = makePanel()
            panel.alphaValue = isShown ? 1 : 0  // screen plugged in mid-session
            panels.append(panel)
        }
        while panels.count > screens.count { panels.removeLast().orderOut(nil) }

        let icons = windows.map(icon(for:))
        if rows.count == screens.count, rows.allSatisfy({ $0.count == windows.count }) {
            for panelRows in rows {
                // Touch only rows that changed: each assignment invalidates and redraws.
                for (i, r) in panelRows.enumerated() where i >= shownWindows.count || shownWindows[i] != windows[i] {
                    r.icon.image = icons[i]
                    r.label.stringValue = Self.text(windows[i])
                }
            }
        } else {
            let height = max(rowHeight, CGFloat(windows.count) * rowHeight) + 16
            rows = []
            for (panel, screen) in zip(panels, screens) {
                // An NSView can only live in one window, so each panel gets its own content.
                let (content, panelRows) = makeContent(windows: windows, icons: icons, height: height)
                rows.append(panelRows)
                panel.setContentSize(NSSize(width: width, height: height))
                panel.contentView = content
                center(panel, on: screen)
            }
        }
        shownWindows = windows
    }

    private func highlight(_ panelRows: [Row], selectedIndex: Int) {
        for (i, r) in panelRows.enumerated() {
            let selected = i == selectedIndex
            r.row.layer?.backgroundColor = selected ? NSColor.selectedContentBackgroundColor.cgColor : nil
            r.label.textColor = selected ? .selectedMenuItemTextColor : .labelColor
        }
    }

    private func icon(for window: WindowInfo) -> NSImage? {
        if let cached = iconCache[window.pid] { return cached }
        let icon = NSRunningApplication(processIdentifier: window.pid)?.icon
        iconCache[window.pid] = icon  // shortcut: never evicted; pids of quit apps linger, fine for a personal tool
        return icon
    }

    /// Every screen by default. `defaults write local.tabswitch allScreens -bool false`
    /// limits it to the active screen (read on each show, no restart needed).
    private static func targetScreens() -> [NSScreen] {
        if UserDefaults.standard.object(forKey: "allScreens") as? Bool ?? true { return NSScreen.screens }
        return NSScreen.main.map { [$0] } ?? Array(NSScreen.screens.prefix(1))
    }

    private static func text(_ w: WindowInfo) -> String { "\(w.appName) — \(w.title)" }

    private func makeContent(windows: [WindowInfo], icons: [NSImage?], height: CGFloat) -> (NSView, [Row]) {
        var panelRows: [Row] = []
        let content = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        content.layer?.cornerRadius = 10

        for (i, w) in windows.enumerated() {
            let y = height - 8 - CGFloat(i + 1) * rowHeight
            let row = NSView(frame: NSRect(x: 8, y: y, width: width - 16, height: rowHeight))
            row.wantsLayer = true
            row.layer?.cornerRadius = 6

            let icon = NSImageView(frame: NSRect(x: 6, y: 4, width: 20, height: 20))
            icon.image = icons[i]
            row.addSubview(icon)

            let label = NSTextField(labelWithString: Self.text(w))
            label.frame = NSRect(x: 34, y: 4, width: width - 16 - 40, height: 20)
            label.lineBreakMode = .byTruncatingTail
            row.addSubview(label)

            content.addSubview(row)
            panelRows.append((row, icon, label))
        }
        return (content, panelRows)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 100),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        // Always ordered in but invisible when idle: must never catch clicks,
        // and must follow the user to every Space / full-screen app.
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        return panel
    }

    private func center(_ panel: NSPanel, on screen: NSScreen) {
        let frame = screen.frame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        ))
    }
}
