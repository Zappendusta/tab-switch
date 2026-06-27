import AppKit
import TabSwitchCore

final class SwitcherPanel {
    private var panel: NSPanel?

    /// Show the panel for `windows` with `selectedIndex` highlighted.
    /// Safe to call repeatedly to update the highlight.
    func show(windows: [WindowInfo], selectedIndex: Int) {
        let rowHeight: CGFloat = 28
        let width: CGFloat = 420
        let height = max(rowHeight, CGFloat(windows.count) * rowHeight) + 16

        let panel = self.panel ?? makePanel()
        self.panel = panel

        let content = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        content.layer?.cornerRadius = 10

        for (i, w) in windows.enumerated() {
            let y = height - 8 - CGFloat(i + 1) * rowHeight
            let row = NSView(frame: NSRect(x: 8, y: y, width: width - 16, height: rowHeight))
            row.wantsLayer = true
            if i == selectedIndex {
                row.layer?.backgroundColor = NSColor.selectedContentBackgroundColor.cgColor
                row.layer?.cornerRadius = 6
            }

            let icon = NSImageView(frame: NSRect(x: 6, y: 4, width: 20, height: 20))
            icon.image = NSRunningApplication(processIdentifier: w.pid)?.icon
            row.addSubview(icon)

            let label = NSTextField(labelWithString: "\(w.appName) — \(w.title)")
            label.frame = NSRect(x: 34, y: 4, width: width - 16 - 40, height: 20)
            label.lineBreakMode = .byTruncatingTail
            label.textColor = (i == selectedIndex) ? .selectedMenuItemTextColor : .labelColor
            row.addSubview(label)

            content.addSubview(row)
        }

        panel.setContentSize(NSSize(width: width, height: height))
        panel.contentView = content
        centerOnActiveScreen(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
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
        return panel
    }

    private func centerOnActiveScreen(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        ))
    }
}
