// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Test",
    platforms: [
        .iOS(.v17)
    ],
    targets: [
        .executableTarget(
            name: "Test",
            path: "Sources"
        )
    ]
)
