import AppKit
import CoreGraphics
import TabSwitchCore

protocol HotkeyTapDelegate: AnyObject {
    func hotkeyOpen(scope: Scope, reverse: Bool)
    func hotkeyNext()
    func hotkeyPrev()
    func hotkeyCancel()
    func hotkeyCommit()
    /// Whether a switch session is currently open (drives commit on release).
    var isSessionOpen: Bool { get }
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
                return me.handle(type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            NSLog("tab-switch: failed to create event tap (Accessibility?)")
            return
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable if the system disabled us.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard let delegate = delegate else { return Unmanaged.passUnretained(event) }
        let flags = event.flags
        let cmd = flags.contains(.maskCommand)
        let option = flags.contains(.maskAlternate)
        let shift = flags.contains(.maskShift)

        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            if keyCode == tabKey && (cmd || option) {
                if delegate.isSessionOpen {
                    delegate.hotkeyNext()
                } else {
                    let scope: Scope = cmd ? .allApps : .activeApp
                    delegate.hotkeyOpen(scope: scope, reverse: shift)
                    // Seed Shift state so an already-held Shift at open time does
                    // not immediately count as a fresh press in flagsChanged.
                    shiftWasDown = shift
                }
                return nil  // consume: system switcher never sees Cmd/Opt+Tab
            }

            if keyCode == escKey && delegate.isSessionOpen {
                delegate.hotkeyCancel()
                return nil
            }
        }

        if type == .flagsChanged && delegate.isSessionOpen {
            if !cmd && !option {
                // Activation modifier released → commit the selection.
                shiftWasDown = false
                delegate.hotkeyCommit()
            } else if shift && !shiftWasDown {
                // Fresh Shift press while still holding the activation modifier
                // → step backward once.
                delegate.hotkeyPrev()
                shiftWasDown = true
            } else {
                shiftWasDown = shift
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
