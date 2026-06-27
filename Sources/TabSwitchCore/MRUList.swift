/// Tracks most-recently-used order of window ids. Front = most recent.
public final class MRUList {
    private var order_: [WindowID] = []

    public init() {}

    /// Move `id` to the front (most recent).
    public func recordFocus(_ id: WindowID) {
        order_.removeAll { $0 == id }
        order_.insert(id, at: 0)
    }

    /// Drop any tracked ids not in `validIDs`.
    public func prune(validIDs: [WindowID]) {
        let valid = Set(validIDs)
        order_.removeAll { !valid.contains($0) }
    }

    /// Sort `windows` by MRU position. Windows we haven't seen keep their
    /// relative input order and come after all known windows.
    public func order(_ windows: [WindowInfo]) -> [WindowInfo] {
        let rank = Dictionary(uniqueKeysWithValues: order_.enumerated().map { ($1, $0) })
        return windows.enumerated().sorted { lhs, rhs in
            let lr = rank[lhs.element.id]
            let rr = rank[rhs.element.id]
            switch (lr, rr) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return lhs.offset < rhs.offset  // stable
            }
        }.map(\.element)
    }
}
