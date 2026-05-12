// swift-tools-version: 5.5
import PackageDescription

let package = Package(
    name: "Test",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .iOSApplication(
            name: "Test",
            targets: ["Test"],
            bundleIdentifier: "com.example.Test",
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "Test",
            path: "Sources"
        )
    ]
)
