// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Nameplate",
    platforms: [.macOS(.v26)],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "Nameplate",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: ".",
            exclude: [
                "Assets", "Tests", "Makefile", "scripts", "README.md", "LICENSE",
                ".github", "dist",
            ],
            sources: ["Sources/Nameplate"],
            resources: [.copy("version.txt"), .process("AppResources")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
            linkerSettings: [
                // SwiftPM places frameworks beside the executable; app bundles use Contents/Frameworks.
                .unsafeFlags([
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path",
                ])
            ],
        ),
        .testTarget(
            name: "NameplateTests",
            dependencies: ["Nameplate"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),
    ]
)
