// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "B",
    products: [
        .library(name: "B", targets: ["B"])
    ],
    targets: [
        .target(name: "B")
    ]
)
