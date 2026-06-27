import ApplicationServices
import CoreGraphics

// Private but long-stable API (used by AltTab and others) to get a window's
// CGWindowID from its AXUIElement. Gives us a stable per-window identifier.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError
