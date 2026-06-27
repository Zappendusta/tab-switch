import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // agent app, no Dock icon

let controller = AppController()

if Permissions.isTrusted() {
    controller.start()
} else {
    NSLog("tab-switch: Accessibility NOT granted, prompting")
    Permissions.requestTrust()
    // Poll until the user grants Accessibility, then start without a relaunch.
    let timer = Timer(timeInterval: 1.0, repeats: true) { t in
        guard Permissions.isTrusted() else { return }
        NSLog("tab-switch: Accessibility granted, starting")
        t.invalidate()
        controller.start()
    }
    RunLoop.main.add(timer, forMode: .common)
}

app.run()
