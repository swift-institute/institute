// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "CollisionRoot",
    dependencies: [
        .package(path: "PATH_X_B"),
        .package(path: "PATH_Y_B"),
    ],
    targets: [
        .target(name: "CollisionRoot")
    ]
)
