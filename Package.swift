// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "institute-application",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "Institute GitHub",
            targets: ["Institute GitHub"]
        ),
        .library(
            name: "Institute Application",
            targets: ["Institute Application"]
        ),
        .library(
            name: "Institute CI Application",
            targets: ["Institute CI Application"]
        ),
        .library(
            name: "Institute Repository Application",
            targets: ["Institute Repository Application"]
        ),
        .library(
            name: "Institute GitHub Application",
            targets: ["Institute GitHub Application"]
        ),
        .library(
            name: "Institute Planner Application",
            targets: ["Institute Planner Application"]
        ),
        .executable(
            name: "institute",
            targets: ["Institute Application CLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-institute/institute.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-arguments.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-environment.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-file-system.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-github.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-git.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-json.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-kernel.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-paths.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-package-manager.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-console.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-4648.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-3339.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-time.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-calendar-gregorian.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-process.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-fips-180-4.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Institute GitHub",
            dependencies: [
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Process", package: "swift-process"),
                .product(name: "RFC 4648", package: "swift-rfc-4648"),
            ]
        ),
        .target(
            name: "Institute CI Application",
            dependencies: [
                "Institute Planner Application",
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute CI Canon", package: "institute"),
                .product(name: "Institute Repository Policy", package: "institute"),
                .product(name: "Console", package: "swift-console"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Institute CI Contract", package: "institute"),
                .product(name: "Institute CI Inventory", package: "institute"),
                .product(name: "Institute CI Model", package: "institute"),
                .product(name: "Institute CI Validation", package: "institute"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Source", package: "institute"),
                .product(name: "Institute Source Policy", package: "institute"),
                .product(name: "Institute Source Workspace", package: "institute"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Package Manager", package: "swift-package-manager"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute Repository Application",
            dependencies: [
                "Institute GitHub",
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Console", package: "swift-console"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "Kernel", package: "swift-kernel"),
                .product(name: "RFC 4648", package: "swift-rfc-4648"),
                .product(name: "RFC 3339", package: "swift-rfc-3339"),
                .product(name: "Time", package: "swift-time"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Repository Policy", package: "institute"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "GitHub", package: "swift-github"),
                .product(name: "GitHub App", package: "swift-github"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Package Manager", package: "swift-package-manager"),
                .product(name: "Process", package: "swift-process"),
                .product(name: "Calendar Gregorian", package: "swift-calendar-gregorian"),
            ]
        ),
        .target(
            name: "Institute Planner Application",
            dependencies: [
                "Institute GitHub",
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Console", package: "swift-console"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Git", package: "swift-git"),
                .product(name: "Institute Installation", package: "institute"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Repository Policy", package: "institute"),
                .product(name: "Institute Source", package: "institute"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute GitHub Application",
            dependencies: [
                "Institute GitHub",
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Console", package: "swift-console"),
                .product(name: "GitHub App", package: "swift-github"),
                .product(name: "Paths", package: "swift-paths"),
            ]
        ),
        .target(
            name: "Institute Application",
            dependencies: [
                "Institute CI Application",
                "Institute GitHub",
                "Institute GitHub Application",
                "Institute Planner Application",
                "Institute Repository Application",
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Institute CI Model", package: "institute"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute Installation", package: "institute"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Repository Policy", package: "institute"),
            ],
            path: "Sources/Institute Application"
        ),
        .executableTarget(
            name: "Institute Application CLI",
            dependencies: [
                "Institute Application",
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Command", package: "swift-arguments"),
            ]
        ),
        .testTarget(
            name: "Institute Application Tests",
            dependencies: [
                "Institute Application",
                "Institute GitHub Application",
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Command", package: "swift-arguments"),
            ],
            path: "Tests/Institute Application Tests"
        ),
        .testTarget(
            name: "Institute Planner Application Tests",
            dependencies: [
                "Institute Planner Application",
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Git", package: "swift-git"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Source", package: "institute"),
                .product(name: "JSON", package: "swift-json"),
            ]
        ),
        .testTarget(
            name: "Institute CI Application Tests",
            dependencies: [
                "Institute CI Application",
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Repository Policy", package: "institute"),
                .product(name: "Institute CI Canon", package: "institute"),
                .product(name: "Institute CI Validation", package: "institute"),
            ]
        ),
        .testTarget(
            name: "Institute Repository Application Tests",
            dependencies: [
                "Institute Repository Application",
                "Institute GitHub",
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Institute Repository Policy", package: "institute"),
                .product(name: "Package Manager", package: "swift-package-manager"),
            ],
            resources: [.process("Fixtures")]
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
