// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "swift-divergent-spelling",
    products: [
        .library(name: "Divergent", targets: ["Divergent"])
    ],
    targets: [
        .target(name: "Divergent")
    ]
)
