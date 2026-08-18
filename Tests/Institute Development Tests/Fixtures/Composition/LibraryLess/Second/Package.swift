// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "Second",
    products: [
        .library(name: "Shared Name", targets: ["Second"])
    ],
    targets: [
        .target(name: "Second")
    ]
)
