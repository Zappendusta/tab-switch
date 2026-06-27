import AppKit
import ApplicationServices

enum Permissions {
    /// True if this process is trusted for Accessibility (required for both
    /// the event tap and AX window control).
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user (system dialog) and opens the Accessibility pane.
    static func requestTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
