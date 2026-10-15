import AppKit
import CoreGraphics
import TabSwitchCore

protocol HotkeyTapDelegate: AnyObject {
    func hotkeyOpen(scope: Scope, reverse: Bool)
    func hotkeyNext()
    func hotkeyPrev()
    func hotkeyCancel()
    func hotkeyCommit()
}

final class HotkeyTap {
    weak var delegate: HotkeyTapDelegate?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let tabKey: Int64 = 0x30      // Tab
    private let escKey: Int64 = 0x35      // Escape

    /// Tracks whether Shift was already held, so each Shift *press* (not hold)
    /// steps the switcher backward exactly once.
    private var shiftWasDown = false

    /// Session state owned by the tap thread, so the callback never waits on the main thread.
    private var sessionOpen = false

    /// Modifiers never auto-repeat, so holding Shift repeats `hotkeyPrev` with a
    /// timer on the tap thread's run loop, at the system key-repeat delay/rate.
    private var shiftRepeat: Timer?
    private let repeatDelay = NSEvent.keyRepeatDelay
    private let repeatInterval = NSEvent.keyRepeatInterval

    /// Creates and enables the tap. Requires Accessibility trust.
    func start() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                let me = Unmanaged<HotkeyTap>.fromOpaque(refcon!).takeUnretainedValue()
                let t0 = CFAbsoluteTimeGetCurrent()  // DEBUG-LAG
                let queuedMs = Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW) &- event.timestamp) / 1e6
                if queuedMs > 20 { lagLog(String(format: "event type=%d waited %.1fms before callback", type.rawValue, queuedMs)) }
                let r = me.handle(type: type, event: event)
                let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
                if ms > 5 { lagLog(String(format: "tap callback type=%d took %.1fms", type.rawValue, ms)) }  // DEBUG-LAG
                return r
            },
            userInfo: selfPtr
        ) else {
            NSLog("tab-switch: failed to create event tap (Accessibility?)")
            return
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        // Own thread: a slow main thread (AX enumerate, panel drawing) must not
        // hold the tap callback, which blocks all keyboard input system-wide.
        let thread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "tab-switch.hotkey-tap"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    private func startShiftRepeat() {
        shiftRepeat?.invalidate()
        shiftRepeat = Timer.scheduledTimer(withTimeInterval: repeatDelay, repeats: false) { [weak self] _ in
            guard let self, self.sessionOpen else { return }
            self.shiftRepeat = Timer.scheduledTimer(withTimeInterval: self.repeatInterval, repeats: true) { [weak self] _ in
                guard let self, self.sessionOpen else { self?.stopShiftRepeat(); return }
                self.send { $0.hotkeyPrev() }
            }
        }
    }

    private func stopShiftRepeat() {
        shiftRepeat?.invalidate()
        shiftRepeat = nil
    }

    /// Delegate work runs on the main thread; the serial main queue keeps event order.
    private func send(_ call: @escaping (HotkeyTapDelegate) -> Void) {
        DispatchQueue.main.async { [weak self] in
            if let delegate = self?.delegate { call(delegate) }
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable if the system disabled us.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            lagLog(String(format: "tap DISABLED type=%d, re-enabling", type.rawValue))  // DEBUG-LAG
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let cmd = flags.contains(.maskCommand)
        let option = flags.contains(.maskAlternate)
        let shift = flags.contains(.maskShift)

        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            if keyCode == tabKey && (cmd || option) {
                if sessionOpen {
                    send { $0.hotkeyNext() }
                } else {
                    let scope: Scope = cmd ? .allApps : .activeApp
                    sessionOpen = true
                    let queued = CFAbsoluteTimeGetCurrent()  // DEBUG-LAG
                    send {
                        lagLog(String(format: "open waited %.1fms for main thread", (CFAbsoluteTimeGetCurrent() - queued) * 1000))  // DEBUG-LAG
                        $0.hotkeyOpen(scope: scope, reverse: shift)
                    }
                    // Seed Shift state so an already-held Shift at open time does
                    // not immediately count as a fresh press in flagsChanged.
                    shiftWasDown = shift
                }
                return nil  // consume: system switcher never sees Cmd/Opt+Tab
            }

            if keyCode == escKey && sessionOpen {
                sessionOpen = false
                stopShiftRepeat()
                send { $0.hotkeyCancel() }
                return nil
            }
        }

        if type == .flagsChanged && sessionOpen {
            if !cmd && !option {
                // Activation modifier released → commit the selection.
                shiftWasDown = false
                sessionOpen = false
                stopShiftRepeat()
                send { $0.hotkeyCommit() }
            } else if shift && !shiftWasDown {
                // Fresh Shift press while still holding the activation modifier
                // → step backward once.
                send { $0.hotkeyPrev() }
                shiftWasDown = true
                startShiftRepeat()
            } else {
                if !shift { stopShiftRepeat() }
                shiftWasDown = shift
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
