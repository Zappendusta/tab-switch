import XCTest
@testable import TabSwitchCore

final class ScopeTests: XCTestCase {
    private func win(_ id: String, pid: Int32) -> WindowInfo {
        WindowInfo(id: WindowID(id), pid: pid, appName: "App", appBundleID: "com.app", title: id, isMinimized: false)
    }

    func testAllAppsKeepsEverything() {
        let windows = [win("a", pid: 1), win("b", pid: 2)]
        let result = Scope.allApps.filter(windows, activePID: 1)
        XCTAssertEqual(result.map(\.id), [WindowID("a"), WindowID("b")])
    }

    func testActiveAppKeepsOnlyActivePID() {
        let windows = [win("a", pid: 1), win("b", pid: 2), win("c", pid: 1)]
        let result = Scope.activeApp.filter(windows, activePID: 1)
        XCTAssertEqual(result.map(\.id), [WindowID("a"), WindowID("c")])
    }
}
