// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Nameplate",
    platforms: [.macOS(.v26)],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "Nameplate",
            path: ".",
            exclude: ["Tests", "Makefile", "README.md", ".github", "dist"],
            sources: ["Sources/Nameplate"],
            resources: [.copy("version.txt")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "NameplateTests",
            dependencies: ["Nameplate"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
