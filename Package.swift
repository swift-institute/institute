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
        .executable(
            name: "institute",
            targets: ["Institute CLI"]
        ),
        .executable(
            name: "institute-linter-runner",
            targets: ["Institute Linter Runner"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-ascii.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-cardinal.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-text.git", branch: "main", traits: ["Byte"]),
        .package(url: "https://github.com/swift-compositions/swift-linter.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-linter-rules.git", branch: "main"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "604.0.0"..<"605.0.0"),
        .package(
            url: "https://github.com/swift-atoms/swift-standard-library-extensions.git",
            branch: "main"
        ),
        .package(url: "https://github.com/swift-atoms/swift-time.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-async-fanout.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-calendar-gregorian.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-diagnostic.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-lint.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-source.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-3339.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-4648.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-fips-180-4.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-github-standard.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-spm-standard.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-xcode-standard.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-arguments.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-console.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-environment.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-file-system.git", branch: "main", traits: ["Threads"]),
        .package(url: "https://github.com/swift-compositions/swift-git.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-github.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-json.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-kernel.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-package-manager.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-paths.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-process.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-threads.git", branch: "main"),
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
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Process", package: "swift-process"),
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
        .target(
            name: "Institute GitHub",
            dependencies: [
                "Institute Model",
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Process", package: "swift-process"),
                .product(name: "RFC 4648", package: "swift-rfc-4648"),
            ]
        ),
        .target(
            name: "Institute Planner",
            dependencies: [
                "Institute GitHub",
                "Institute Installation",
                "Institute Model",
                "Institute Repository Policy",
                "Source Report",
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Git", package: "swift-git"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute Command",
            dependencies: [
                "Institute CI Canon",
                "Institute CI Contract",
                "Institute CI Model",
                "Institute CI Validation",
                "Institute GitHub",
                "Institute Installation",
                "Institute Model",
                "Institute Planner",
                "Institute Repository Policy",
                "Institute Source",
                "Institute Source Policy",
                "Institute Source Workspace",
                "Source Report",
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Calendar Gregorian", package: "swift-calendar-gregorian"),
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Console", package: "swift-console"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Git", package: "swift-git"),
                .product(name: "GitHub App", package: "swift-github"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Package Manager", package: "swift-package-manager"),
                .product(name: "Paths", package: "swift-paths"),
                .product(name: "Process", package: "swift-process"),
                .product(name: "RFC 3339", package: "swift-rfc-3339"),
                .product(name: "Time", package: "swift-time"),
            ]
        ),
        .executableTarget(
            name: "Institute CLI",
            dependencies: [
                "Institute Command",
                "Institute Model",
                .product(name: "Command", package: "swift-arguments"),
            ]
        ),
        .testTarget(
            name: "Institute Planner Tests",
            dependencies: [
                "Institute Model",
                "Institute Planner",
                "Source Report",
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Git", package: "swift-git"),
                .product(name: "JSON", package: "swift-json"),
            ]
        ),
        .testTarget(
            name: "Institute Command Tests",
            dependencies: [
                "Institute CI Canon",
                "Institute CI Model",
                "Institute CI Validation",
                "Institute Command",
                "Institute Model",
                "Institute Repository Policy",
                "Source Report",
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Package Manager", package: "swift-package-manager"),
            ],
            resources: [.process("Repository/Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)

let linterRuleTargets: [Target] = [
        .target(
            name: "Institute Linter Rule Architecture",
            dependencies: [
                .target(name: "Institute Model"),
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Institute Linter Rule Manifest"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Naming",
            dependencies: [
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Foundation",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Framework",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Byte",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Conformance",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Closure",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Idiom",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Manifest",
            dependencies: [
                .target(name: "Institute Model"),
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SPM Standard", package: "swift-spm-standard"),
                .product(name: "Byte", package: "swift-byte"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Memory",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Platform",
            dependencies: [
                .target(name: "Institute Model"),
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Institute Linter Rule Manifest"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Structure",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Institute Linter Rule Manifest"),
                .product(name: "Linter Rule Structure", package: "swift-linter-rules"),
                .product(name: "Cardinal", package: "swift-cardinal"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Testing",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Institute Linter Rule Manifest"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Throws",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Try",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Unchecked",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule RawValue",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Cardinal",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftOperators", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Linter Institute Rules",
            dependencies: [
                .target(name: "Institute Model"),
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Institute Linter Rule Architecture"),
                .target(name: "Institute Linter Rule Naming"),
                .target(name: "Institute Linter Rule Foundation"),
                .target(name: "Institute Linter Rule Framework"),
                .target(name: "Institute Linter Rule Byte"),
                .target(name: "Institute Linter Rule Conformance"),
                .target(name: "Institute Linter Rule Closure"),
                .target(name: "Institute Linter Rule Idiom"),
                .target(name: "Institute Linter Rule Manifest"),
                .target(name: "Institute Linter Rule Memory"),
                .target(name: "Institute Linter Rule Platform"),
                .target(name: "Institute Linter Rule Structure"),
                .target(name: "Institute Linter Rule Testing"),
                .target(name: "Institute Linter Rule Throws"),
                .target(name: "Institute Linter Rule Try"),
                .target(name: "Institute Linter Rule Unchecked"),
                .target(name: "Institute Linter Rule RawValue"),
                .target(name: "Institute Linter Rule Cardinal"),
                .product(name: "Linter Rules", package: "swift-linter-rules"),
                .product(name: "Linter Rule Feature", package: "swift-linter-rules"),
                .product(name: "Linter Rule Framework", package: "swift-linter-rules"),
                .product(name: "Linter Rule SwiftUI", package: "swift-linter-rules"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Architecture Tests",
            dependencies: [
                .target(name: "Institute Linter Rule Architecture"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Naming Tests",
            dependencies: [
                .target(name: "Institute Linter Rule Naming"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Foundation Tests",
            dependencies: [
                .target(name: "Institute Linter Rule Foundation"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Framework Tests",
            dependencies: [
                .target(name: "Institute Linter Rule Framework"),
                .product(name: "Linter Rule Testing", package: "swift-linter-rules"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Byte Tests",
            dependencies: [
                .target(name: "Institute Linter Rule Byte"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Closure Tests",
            dependencies: [
                .target(name: "Institute Linter Rule Closure"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Idiom Tests",
            dependencies: [
                .target(name: "Institute Linter Rule Idiom"),
                .product(name: "Linter Rule Testing", package: "swift-linter-rules"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "Text", package: "swift-text"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Manifest Tests",
            dependencies: [
                .target(name: "Institute Model"),
                .target(name: "Institute Linter Rule Manifest"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Memory Tests",
            dependencies: [
                .target(name: "Institute Linter Rule Memory"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Platform Tests",
            dependencies: [
                .target(name: "Institute Linter Rule Platform"),
                .product(name: "Linter Rule Testing", package: "swift-linter-rules"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Structure Tests",
            dependencies: [
                .target(name: "Institute Linter Rule Structure"),
                .product(name: "Linter Rule Structure", package: "swift-linter-rules"),
                .product(name: "Linter Rule Testing", package: "swift-linter-rules"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Testing Tests",
            dependencies: [
                .target(name: "Institute Linter Rule Testing"),
                .product(name: "Linter Rule Testing", package: "swift-linter-rules"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "Text", package: "swift-text"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Throws Tests",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Institute Linter Rule Throws"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Try Tests",
            dependencies: [
                .target(name: "Institute Linter Rule Try"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Unchecked Tests",
            dependencies: [
                .target(name: "Institute Linter Rule Unchecked"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule RawValue Tests",
            dependencies: [
                .target(name: "Institute Linter Rule RawValue"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Cardinal Tests",
            dependencies: [
                .target(name: "Institute Linter Rule Cardinal"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Linter Institute Rules Tests",
            dependencies: [
                .target(name: "Linter Institute Rules"),
                .product(name: "Linter Rules", package: "swift-linter-rules"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
            ]
        ),
        .target(
            name: "Primitives Linter Rule Tower",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Linter Primitives Rules",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Primitives Linter Rule Tower"),
                .target(name: "Linter Institute Rules"),
            ]
        ),
        .testTarget(
            name: "Linter Primitives Rules Tests",
            dependencies: [
                .target(name: "Linter Primitives Rules"),
                .product(name: "Lint", package: "swift-lint"),
            ]
        ),
        .testTarget(
            name: "Primitives Linter Rule Tower Tests",
            dependencies: [
                .target(name: "Primitives Linter Rule Tower"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Linter Standards Rules",
            dependencies: [
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Linter Institute Rules"),
                .target(name: "Institute Linter Rule Naming"),
                .target(name: "Institute Linter Rule Structure"),
            ]
        ),
        .testTarget(
            name: "Linter Standards Rules Tests",
            dependencies: [
                .target(name: "Linter Standards Rules"),
                .product(name: "Lint", package: "swift-lint"),
                .target(name: "Linter Institute Rules"),
                .target(name: "Institute Linter Rule Naming"),
                .target(name: "Institute Linter Rule Structure"),
                .target(name: "Institute Linter Rule Testing"),
            ]
        ),
    .executableTarget(
        name: "Institute Linter Runner",
        dependencies: [
            .product(name: "Linter", package: "swift-linter"),
            .target(name: "Linter Institute Rules"),
            .target(name: "Linter Primitives Rules"),
            .target(name: "Linter Standards Rules"),
            .target(name: "Institute Model"),
            .product(name: "Environment", package: "swift-environment"),
        ]
    ),
]
for target in linterRuleTargets {
    target.swiftSettings = vendoredSourceSettings + [.treatAllWarnings(as: .error)]
}
package.targets += linterRuleTargets

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
