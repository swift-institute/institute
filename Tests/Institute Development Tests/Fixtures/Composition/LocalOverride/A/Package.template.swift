// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "A",
    products: [
        .library(name: "A", targets: ["A"])
    ],
    dependencies: [
        .package(url: "REMOTE_B_URL", branch: "main")
    ],
    targets: [
        .target(name: "A", dependencies: [.product(name: "B", package: "B")])
    ]
)
