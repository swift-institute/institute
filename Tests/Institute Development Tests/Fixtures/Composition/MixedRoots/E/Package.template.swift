// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "E",
    dependencies: [
        .package(path: "PATH_B"),
        .package(path: "PATH_D"),
    ],
    targets: [
        .target(
            name: "E",
            dependencies: [
                .product(name: "B", package: "B"),
                .product(name: "D", package: "D"),
            ]
        )
    ]
)
