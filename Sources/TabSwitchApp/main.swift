import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // agent app, no Dock icon

guard Permissions.isTrusted() else {
    NSLog("tab-switch: Accessibility NOT granted, prompting")
    Permissions.requestTrust()
    // Re-launch after granting permission.
    app.run()
    exit(0)
}

let controller = AppController()
controller.start()
app.run()
