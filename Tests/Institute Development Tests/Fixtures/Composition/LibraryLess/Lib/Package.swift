// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "Lib",
    products: [
        .library(name: "Shared Name", targets: ["Lib"])
    ],
    targets: [
        .target(name: "Lib")
    ]
)
