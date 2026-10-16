// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DockSnap",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "DockSnap",
            path: "Sources/DockSnap"
        )
    ]
)
