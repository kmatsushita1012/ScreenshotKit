// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ScreenshotKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ScreenshotKit",
            targets: ["ScreenshotKit"]
        ),
        .executable(
            name: "screenshotkit-export",
            targets: ["ScreenshotKitExport"]
        ),
    ],
    targets: [
        .target(
            name: "ScreenshotKit",
            resources: [
                .process("Media.xcassets")
            ]
        ),
        .executableTarget(
            name: "ScreenshotKitExport"
        ),
        .testTarget(
            name: "ScreenshotKitTests",
            dependencies: ["ScreenshotKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
