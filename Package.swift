// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Test",
    platforms: [
        .iOS("26.0")
    ],
    products: [
        .iOSApplication(
            name: "Test",
            targets: ["Test"],
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .star),
            accentColor: .presetColor(.blue),
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
            path: "Sources",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        )
    ]
)
