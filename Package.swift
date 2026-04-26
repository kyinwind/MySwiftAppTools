// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MySwiftAppTools",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MySwiftAppTools",
            targets: ["MySwiftAppTools"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MySwiftAppTools",
            exclude: ["DesignSystem/README.md"],
            resources: [
                .process("Resources/en.lproj"),
                .process("Resources/zh-Hans.lproj")
            ]
        ),

    ],
    swiftLanguageModes: [.v6]
)
