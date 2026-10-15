/// State for a single switch session.
public final class SwitcherState {
    public let windows: [WindowInfo]
    public private(set) var selectedIndex: Int

    public init(windows: [WindowInfo]) {
        self.windows = windows
        // Pre-select the previous window (index 1) when there are 2+ windows.
        self.selectedIndex = windows.count >= 2 ? 1 : 0
    }

    public var selected: WindowInfo? {
        guard windows.indices.contains(selectedIndex) else { return nil }
        return windows[selectedIndex]
    }

    /// Select the window with `id`, if present. Keeps the selection stable when
    /// the window list is refreshed mid-session.
    public func select(_ id: WindowID) {
        if let i = windows.firstIndex(where: { $0.id == id }) { selectedIndex = i }
    }

    public func next() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
    }

    public func prev() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
    }
}
