// swift-tools-version: 6.4

import PackageDescription

let vendoredSourceSettings: [SwiftSetting] = [
    .enableExperimentalFeature("Lifetimes"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "institute",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "Institute Installation",
            targets: ["Institute Installation"]
        ),
        .library(
            name: "Institute Model",
            targets: ["Institute Model"]
        ),
        .library(
            name: "Institute Source Workspace",
            targets: ["Institute Source Workspace"]
        ),
        .library(
            name: "Institute Source Policy",
            targets: ["Institute Source Policy"]
        ),
        .library(
            name: "Institute CI Model",
            targets: ["Institute CI Model"]
        ),
        .library(
            name: "Institute CI Canon",
            targets: ["Institute CI Canon"]
        ),
        .library(
            name: "Institute CI Contract",
            targets: ["Institute CI Contract"]
        ),
        .library(
            name: "Institute CI Inventory",
            targets: ["Institute CI Inventory"]
        ),
        .library(
            name: "Institute CI Validation",
            targets: ["Institute CI Validation"]
        ),
        .library(
            name: "Institute CI Workflow",
            targets: ["Institute CI Workflow"]
        ),
        .library(
            name: "Institute Repository Policy",
            targets: ["Institute Repository Policy"]
        ),
        .library(
            name: "Institute Source Profile",
            targets: ["Institute Source Profile"]
        ),
        .library(
            name: "Institute Source",
            targets: ["Institute Source"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-ascii.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-async-fanout.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-environment.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-file-system.git", branch: "main", traits: ["Threads"]),
        .package(url: "https://github.com/swift-compositions/swift-git.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-json.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-kernel.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-package-manager.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-process.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-threads.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-xcode-standard.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-source.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-diagnostic.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-lint.git", branch: "main"),
        .package(
            url: "https://github.com/swift-compositions/swift-institute-linter-rules.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-primitives-linter-rules.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-standards/swift-standards-linter-rules.git",
            branch: "main"
        ),
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-fips-180-4.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-github-standard.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-spm-standard.git", branch: "main"),
        .package(
            url: "https://github.com/swift-atoms/swift-standard-library-extensions.git",
            branch: "main"
        ),
    ],
    targets: [
        .target(
            name: "Source Measurement",
            dependencies: [
                .product(name: "Source", package: "swift-source"),
                .product(name: "Diagnostic", package: "swift-diagnostic"),
                .product(name: "JSON", package: "swift-json"),
            ],
            swiftSettings: vendoredSourceSettings
        ),
        .target(
            name: "Source Profile",
            dependencies: [
                "Source Measurement",
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "JSON", package: "swift-json"),
            ],
            swiftSettings: vendoredSourceSettings
        ),
        .target(
            name: "Source Swift Format",
            dependencies: ["Source Measurement", "Source Profile"],
            swiftSettings: vendoredSourceSettings
        ),
        .target(
            name: "Source SwiftLint",
            dependencies: [
                "Source Measurement",
                "Source Profile",
                .product(name: "JSON", package: "swift-json"),
            ],
            swiftSettings: vendoredSourceSettings
        ),
        .target(
            name: "Source Linter",
            dependencies: [
                "Source Measurement",
                "Source Profile",
                .product(name: "JSON", package: "swift-json"),
            ],
            swiftSettings: vendoredSourceSettings
        ),
        .target(
            name: "Source Execution",
            dependencies: [
                "Source Measurement",
                "Source Profile",
                "Source Swift Format",
                "Source SwiftLint",
                "Source Linter",
            ],
            swiftSettings: vendoredSourceSettings
        ),
        .target(
            name: "Source Report",
            dependencies: [
                "Source Measurement", "Source Profile", .product(name: "JSON", package: "swift-json"),
            ],
            swiftSettings: vendoredSourceSettings
        ),
        .target(
            name: "Source Repair",
            dependencies: [
                .product(name: "Source", package: "swift-source"),
                "Source Measurement",
                "Source Profile",
                "Source Report",
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "JSON", package: "swift-json"),
            ],
            swiftSettings: vendoredSourceSettings
        ),
        .target(
            name: "Institute Installation",
            dependencies: [
                "Institute Model",
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Kernel", package: "swift-kernel"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute Model",
            dependencies: [
                .product(name: "Async Fanout", package: "swift-async-fanout"),
                .product(name: "Kernel", package: "swift-kernel"),
            ]
        ),
        .target(
            name: "Institute Source Workspace",
            dependencies: [
                "Institute Model",
                "Institute Source Policy",
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "Git", package: "swift-git"),
                "Source Measurement",
                .product(name: "SPM Standard", package: "swift-spm-standard"),
            ]
        ),
        .target(
            name: "Institute Source Policy",
            dependencies: [
                "Institute Model",
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                "Source Profile",
            ]
        ),
        .target(
            name: "Institute CI Model",
            dependencies: [
                "Institute Model"
            ]
        ),
        .target(
            name: "Institute CI Canon",
            dependencies: [
                "Institute CI Model",
                "Institute Model",
                .product(name: "ASCII", package: "swift-ascii"),
            ]
        ),
        .target(
            name: "Institute CI Contract",
            dependencies: [
                "Institute CI Model",
                "Institute Model",
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
            ]
        ),
        .target(
            name: "Institute CI Workflow",
            dependencies: [
                .product(name: "GitHub Standard", package: "swift-github-standard"),
                "Institute CI Model",
                "Institute Model",
            ]
        ),
        .target(
            name: "Institute CI Inventory",
            dependencies: [
                .product(name: "JSON", package: "swift-json"),
                .product(name: "GitHub Standard", package: "swift-github-standard"),
                "Institute CI Model",
                "Institute CI Workflow",
                "Institute Model",
                .product(name: "File System", package: "swift-file-system"),
            ]
        ),
        .target(
            name: "Institute CI Validation",
            dependencies: [
                "Institute CI Canon",
                "Institute CI Inventory",
                "Institute CI Model",
                "Institute CI Workflow",
                "Institute Model",
                .product(name: "ASCII", package: "swift-ascii"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "GitHub Standard", package: "swift-github-standard"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Package Manager", package: "swift-package-manager"),
                .product(name: "Process", package: "swift-process"),
                .product(
                    name: "Standard Library Extensions",
                    package: "swift-standard-library-extensions"
                ),
            ]
        ),
        .target(
            name: "Institute Repository Policy",
            dependencies: [
                "Institute Model",
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Package Manager", package: "swift-package-manager"),
            ]
        ),
        .target(
            name: "Institute Source Profile",
            dependencies: [
                "Institute Model",
                "Institute Source Policy",
                .product(
                    name: "Linter Institute Rules",
                    package: "swift-institute-linter-rules"
                ),
                .product(
                    name: "Linter Primitives Rules",
                    package: "swift-primitives-linter-rules"
                ),
                .product(
                    name: "Linter Standards Rules",
                    package: "swift-standards-linter-rules"
                ),
                .product(name: "Lint", package: "swift-lint"),
                "Source Measurement",
                "Source Profile",
            ]
        ),
        .target(
            name: "Institute Source",
            dependencies: [
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "JSON", package: "swift-json"),
                "Institute Model",
                "Institute Source Policy",
                "Institute Source Profile",
                "Institute Source Workspace",
                .product(name: "Async Fanout", package: "swift-async-fanout"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "Process", package: "swift-process"),
                "Source Execution",
                "Source Measurement",
                "Source Profile",
                "Source Repair",
                "Source Linter",
                "Source Report",
                "Source Swift Format",
                "Source SwiftLint",
                .product(name: "Thread Pool", package: "swift-threads"),
            ]
        ),
        .testTarget(
            name: "Institute Tests",
            dependencies: [
                "Institute Installation",
                "Institute Model",
                "Institute Source",
                "Institute Source Policy",
                "Institute Source Profile",
                "Institute Source Workspace",
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Git", package: "swift-git"),
                .product(name: "JSON", package: "swift-json"),
                "Source Execution",
                "Source Measurement",
                "Source Profile",
                "Source Repair",
                "Source Report",
                "Source Swift Format",
                "Source SwiftLint",
                .product(name: "Xcode Workspace Standard", package: "swift-xcode-standard"),
            ],
            path: "Tests/Institute Tests"
        ),
        .testTarget(
            name: "Institute CI Model Tests",
            dependencies: ["Institute CI Model"]
        ),
        .testTarget(
            name: "Institute CI Canon Tests",
            dependencies: ["Institute CI Canon"]
        ),
        .testTarget(
            name: "Institute CI Workflow Tests",
            dependencies: [
                .product(name: "GitHub Standard", package: "swift-github-standard"),
                "Institute CI Model",
                "Institute CI Workflow",
            ]
        ),
        .testTarget(
            name: "Institute Repository Policy Tests",
            dependencies: [
                "Institute Repository Policy",
                "Institute Model",
                .product(name: "JSON", package: "swift-json"),
            ]
        ),
        .testTarget(
            name: "Institute Source Policy Tests",
            dependencies: [
                .product(name: "JSON", package: "swift-json"),
                "Institute Source Policy",
                "Institute Model",
                "Source Profile",
            ]
        ),
        .testTarget(
            name: "Institute CI Inventory Tests",
            dependencies: [.product(name: "GitHub Standard", package: "swift-github-standard"), "Institute CI Inventory"],
            exclude: ["Fixtures"]
        ),
        .testTarget(
            name: "Institute CI Validation Tests",
            dependencies: [
                .product(name: "GitHub Standard", package: "swift-github-standard"),
                "Institute CI Inventory",
                "Institute CI Validation",
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Process", package: "swift-process"),
            ],
            exclude: ["Fixtures"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        ]
}
