import XCTest
@testable import TabSwitchCore

final class SwitcherStateTests: XCTestCase {
    private func wins(_ ids: [String]) -> [WindowInfo] {
        ids.map { WindowInfo(id: WindowID($0), pid: 1, appName: "App", appBundleID: "com.app", title: $0, isMinimized: false) }
    }

    func testInitialSelectionIsPreviousWindow() {
        let state = SwitcherState(windows: wins(["a", "b", "c"]))
        XCTAssertEqual(state.selectedIndex, 1)
        XCTAssertEqual(state.selected?.id.raw, "b")
    }

    func testSingleWindowSelectsItself() {
        let state = SwitcherState(windows: wins(["a"]))
        XCTAssertEqual(state.selectedIndex, 0)
        XCTAssertEqual(state.selected?.id.raw, "a")
    }

    func testEmptyHasNoSelection() {
        let state = SwitcherState(windows: wins([]))
        XCTAssertNil(state.selected)
    }

    func testNextWrapsAround() {
        let state = SwitcherState(windows: wins(["a", "b", "c"]))  // starts at index 1
        state.next()  // -> 2
        XCTAssertEqual(state.selected?.id.raw, "c")
        state.next()  // wrap -> 0
        XCTAssertEqual(state.selected?.id.raw, "a")
    }

    func testPrevWrapsAround() {
        let state = SwitcherState(windows: wins(["a", "b", "c"]))  // starts at index 1
        state.prev()  // -> 0
        XCTAssertEqual(state.selected?.id.raw, "a")
        state.prev()  // wrap -> 2
        XCTAssertEqual(state.selected?.id.raw, "c")
    }
}
