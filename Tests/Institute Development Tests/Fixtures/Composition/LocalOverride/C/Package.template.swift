// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "C",
    dependencies: [
        .package(path: "PATH_A"),
        .package(path: "PATH_B_LOCAL"),
    ],
    targets: [
        .target(
            name: "C",
            dependencies: [
                .product(name: "A", package: "A"),
                .product(name: "B", package: "B"),
            ]
        )
    ]
)
