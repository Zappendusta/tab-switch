// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "tab-switch",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "TabSwitchCore"),
        .executableTarget(
            name: "TabSwitchApp",
            dependencies: ["TabSwitchCore"]
        ),
        .testTarget(
            name: "TabSwitchCoreTests",
            dependencies: ["TabSwitchCore"]
        ),
    ]
)
