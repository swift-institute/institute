// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "swift-witness-exemption-fixture",
    products: [
        .library(name: "Fixture", targets: ["Fixture"]),
    ],
    targets: [
        .target(name: "Fixture"),
    ],
    swiftLanguageModes: [.v6]
)
