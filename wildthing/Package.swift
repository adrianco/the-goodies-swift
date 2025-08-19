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
        .package(path: "../inbetweenies")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Wildthing",
            dependencies: [
                .product(name: "Inbetweenies", package: "inbetweenies")
            ]),
        .testTarget(
            name: "WildthingTests",
            dependencies: ["Wildthing"]),
    ]
)
