public enum Scope {
    case allApps
    case activeApp

    /// Returns the windows relevant to this scope, preserving input order.
    public func filter(_ windows: [WindowInfo], activePID: Int32) -> [WindowInfo] {
        switch self {
        case .allApps:
            return windows
        case .activeApp:
            return windows.filter { $0.pid == activePID }
        }
    }
}
