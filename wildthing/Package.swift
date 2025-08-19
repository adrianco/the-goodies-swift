// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Wildthing",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Wildthing",
            targets: ["Wildthing"]),
    ],
    dependencies: [
        .package(path: "../inbetweenies"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Wildthing",
            dependencies: [
                .product(name: "Inbetweenies", package: "inbetweenies"),
                .product(name: "SQLite", package: "SQLite.swift")
            ]),
        .testTarget(
            name: "WildthingTests",
            dependencies: ["Wildthing"]),
    ]
)
