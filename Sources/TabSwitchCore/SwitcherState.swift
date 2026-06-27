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

    public func next() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
    }

    public func prev() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
    }
}
