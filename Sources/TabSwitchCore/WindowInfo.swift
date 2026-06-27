import Foundation

/// Stable-within-a-session identifier for a window.
public struct WindowID: Hashable, Equatable {
    public let raw: String
    public init(_ raw: String) { self.raw = raw }
}

/// Plain value describing a window. No AppKit/AX types so Core stays testable.
public struct WindowInfo: Equatable {
    public let id: WindowID
    public let pid: Int32
    public let appName: String
    public let appBundleID: String
    public let title: String
    public let isMinimized: Bool

    public init(id: WindowID, pid: Int32, appName: String, appBundleID: String, title: String, isMinimized: Bool) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.appBundleID = appBundleID
        self.title = title
        self.isMinimized = isMinimized
    }
}
