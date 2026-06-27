import XCTest
@testable import TabSwitchCore

final class MRUListTests: XCTestCase {
    private func win(_ id: String) -> WindowInfo {
        WindowInfo(id: WindowID(id), pid: 1, appName: "App", appBundleID: "com.app", title: id, isMinimized: false)
    }

    func testUnknownWindowsKeepInputOrderStably() {
        let mru = MRUList()
        let ordered = mru.order([win("a"), win("b"), win("c")])
        XCTAssertEqual(ordered.map(\.id.raw), ["a", "b", "c"])
    }

    func testRecordFocusMovesToFront() {
        let mru = MRUList()
        mru.recordFocus(WindowID("c"))
        mru.recordFocus(WindowID("a"))
        // MRU order is now: a (most recent), c, then unknowns in input order.
        let ordered = mru.order([win("a"), win("b"), win("c")])
        XCTAssertEqual(ordered.map(\.id.raw), ["a", "c", "b"])
    }

    func testPruneRemovesStaleIDs() {
        let mru = MRUList()
        mru.recordFocus(WindowID("x"))
        mru.recordFocus(WindowID("a"))
        mru.prune(validIDs: [WindowID("a")])
        let ordered = mru.order([win("a"), win("b")])
        // "x" is gone; "a" is most recent, "b" unknown follows.
        XCTAssertEqual(ordered.map(\.id.raw), ["a", "b"])
    }
}
