// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DockSnap",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DockSnap", targets: ["DockSnap"])
    ],
    targets: [
        .executableTarget(
            name: "DockSnap",
            path: "Sources/DockSnap"
        ),
        .testTarget(
            name: "DockSnapTests",
            dependencies: ["DockSnap"],
            path: "Tests/DockSnapTests"
        )
    ]
)
