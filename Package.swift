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
            name: "Institute Source Application",
            targets: ["Institute Source Application"]
        ),
        .library(
            name: "Institute Certification Application",
            targets: ["Institute Certification Application"]
        ),
        .library(
            name: "Institute Coherence Application",
            targets: ["Institute Coherence Application"]
        ),
        .library(
            name: "Institute Composition Application",
            targets: ["Institute Composition Application"]
        ),
        .library(
            name: "Institute Context Application",
            targets: ["Institute Context Application"]
        ),
        .library(
            name: "Institute Conversion Application",
            targets: ["Institute Conversion Application"]
        ),
        .library(
            name: "Institute Dependency Application",
            targets: ["Institute Dependency Application"]
        ),
        .library(
            name: "Institute Doctor Application",
            targets: ["Institute Doctor Application"]
        ),
        .library(
            name: "Institute GitHub Application",
            targets: ["Institute GitHub Application"]
        ),
        .library(
            name: "Institute Inventory Application",
            targets: ["Institute Inventory Application"]
        ),
        .library(
            name: "Institute Navigation Application",
            targets: ["Institute Navigation Application"]
        ),
        .library(
            name: "Institute Package Application",
            targets: ["Institute Package Application"]
        ),
        .library(
            name: "Institute Verification Application",
            targets: ["Institute Verification Application"]
        ),
        .library(
            name: "Institute Workspace Application",
            targets: ["Institute Workspace Application"]
        ),
        .library(
            name: "Institute Architecture Model",
            targets: ["Institute Architecture Model"]
        ),
        .library(
            name: "Institute Architecture Facts",
            targets: ["Institute Architecture Facts"]
        ),
        .library(
            name: "Institute Architecture Graph",
            targets: ["Institute Architecture Graph"]
        ),
        .library(
            name: "Institute Architecture Index",
            targets: ["Institute Architecture Index"]
        ),
        .library(
            name: "Institute Architecture Validation",
            targets: ["Institute Architecture Validation"]
        ),
        .library(
            name: "Institute Architecture Candidates",
            targets: ["Institute Architecture Candidates"]
        ),
        .library(
            name: "Institute Architecture Migration",
            targets: ["Institute Architecture Migration"]
        ),
        .library(
            name: "Institute Architecture CLI",
            targets: ["Institute Architecture CLI"]
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
        .package(url: "https://github.com/swift-standards/swift-spm-standard.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Institute Architecture Model",
            dependencies: [
                .product(name: "Institute Model", package: "institute")
            ]
        ),
        .target(
            name: "Institute Architecture Facts",
            dependencies: [
                "Institute Architecture Model",
                "Institute Architecture Graph",
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "JSON", package: "swift-json"),
            ]
        ),
        .target(
            name: "Institute Architecture Graph",
            dependencies: [
                "Institute Architecture Model",
                .product(name: "Institute Model", package: "institute"),
            ]
        ),
        .target(
            name: "Institute Architecture Index",
            dependencies: [
                "Institute Architecture Model",
                "Institute Architecture Graph",
                "Institute Architecture Facts",
                "Institute Architecture Validation",
                .product(name: "Institute Model", package: "institute"),
            ]
        ),
        .target(
            name: "Institute Architecture Validation",
            dependencies: [
                "Institute Architecture Model",
                "Institute Architecture Graph",
                "Institute Architecture Facts",
                .product(name: "Institute Model", package: "institute"),
            ]
        ),
        .target(
            name: "Institute Architecture Candidates",
            dependencies: [
                "Institute Architecture Model",
                .product(name: "Institute Model", package: "institute"),
            ]
        ),
        .target(
            name: "Institute Architecture Migration",
            dependencies: [
                "Institute Architecture Model",
                .product(name: "Institute Model", package: "institute"),
            ]
        ),
        .target(
            name: "Institute Architecture CLI",
            dependencies: [
                "Institute Architecture Model",
                "Institute Architecture Facts",
                "Institute Architecture Graph",
                "Institute Architecture Index",
                "Institute Architecture Validation",
                "Institute Architecture Candidates",
                "Institute Architecture Migration",
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Kernel", package: "swift-kernel"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute GitHub",
            dependencies: [
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Dependency", package: "institute"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute CI Application",
            dependencies: [
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
            name: "Institute Source Application",
            dependencies: [
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Source", package: "institute"),
                .product(name: "Institute Source Workspace", package: "institute"),
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute Workspace Application",
            dependencies: [
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Development", package: "institute"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute Doctor Application",
            dependencies: [
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Doctor", package: "institute"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute Inventory Application",
            dependencies: [
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Doctor", package: "institute"),
                .product(name: "Institute Inventory", package: "institute"),
                .product(name: "Institute Pages", package: "institute"),
                .product(name: "Console", package: "swift-console"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute Dependency Application",
            dependencies: [
                "Institute GitHub",
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Dependency", package: "institute"),
                .product(name: "Institute Inventory", package: "institute"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Git", package: "swift-git"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute Composition Application",
            dependencies: [
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Development", package: "institute"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
            ]
        ),
        .target(
            name: "Institute Context Application",
            dependencies: [
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Development", package: "institute"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute Navigation Application",
            dependencies: [
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Development", package: "institute"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
            ]
        ),
        .target(
            name: "Institute Package Application",
            dependencies: [
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Build Coordinator", package: "institute"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute Coherence Application",
            dependencies: [
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Instruments", package: "institute"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute Conversion Application",
            dependencies: [
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Conversion", package: "institute"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Console", package: "swift-console"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "JSON", package: "swift-json"),
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
            name: "Institute Verification Application",
            dependencies: [
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Instruments", package: "institute"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Console", package: "swift-console"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Git", package: "swift-git"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute Certification Application",
            dependencies: [
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Instruments", package: "institute"),
                .product(name: "Institute Doctor", package: "institute"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Console", package: "swift-console"),
                .product(name: "Environment", package: "swift-environment"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Git", package: "swift-git"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Package Manager", package: "swift-package-manager"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .target(
            name: "Institute Application",
            dependencies: [
                "Institute CI Application",
                "Institute Certification Application",
                "Institute Coherence Application",
                "Institute Composition Application",
                "Institute Context Application",
                "Institute Conversion Application",
                "Institute Dependency Application",
                "Institute Doctor Application",
                "Institute GitHub Application",
                "Institute Inventory Application",
                "Institute Navigation Application",
                "Institute Package Application",
                "Institute Verification Application",
                "Institute Workspace Application",
                "Institute Repository Application",
                "Institute Source Application",
                "Institute Architecture CLI",
                "Institute Architecture Model",
                "Institute GitHub",
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "Command Schema", package: "swift-arguments"),
                .product(name: "Institute CI Model", package: "institute"),
                .product(name: "Institute Conversion", package: "institute"),
                .product(name: "Institute Dependency", package: "institute"),
                .product(name: "Institute Development", package: "institute"),
                .product(name: "Institute Doctor", package: "institute"),
                .product(name: "Institute Instruments", package: "institute"),
                .product(name: "Institute Inventory", package: "institute"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Repository Policy", package: "institute"),
            ],
            path: "Sources/Institute Application"
        ),
        .executableTarget(
            name: "Institute Application CLI",
            dependencies: [
                "Institute Application",
                "Institute Workspace Application",
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Command", package: "swift-arguments"),
            ]
        ),
        .testTarget(
            name: "Institute Architecture Tests",
            dependencies: [
                "Institute Architecture Model",
                "Institute Architecture Facts",
                "Institute Architecture Graph",
                "Institute Architecture Index",
                "Institute Architecture Validation",
                "Institute Architecture Candidates",
                "Institute Architecture Migration",
                "Institute Architecture CLI",
                .product(name: "Institute Model", package: "institute"),
            ],
            path: "Tests/Institute Architecture Tests"
        ),
        .testTarget(
            name: "Institute Source Application Tests",
            dependencies: [
                "Institute Source Application",
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Source", package: "institute"),
            ]
        ),
        .testTarget(
            name: "Institute Application Tests",
            dependencies: [
                "Institute Application",
                "Institute Certification Application",
                "Institute Coherence Application",
                "Institute Composition Application",
                "Institute Context Application",
                "Institute Conversion Application",
                "Institute Dependency Application",
                "Institute Doctor Application",
                "Institute GitHub Application",
                "Institute Inventory Application",
                "Institute Navigation Application",
                "Institute Package Application",
                "Institute Verification Application",
                "Institute Workspace Application",
                .product(name: "Institute Build Coordinator", package: "institute"),
                .product(name: "Institute Model", package: "institute"),
                .product(name: "Institute Instruments", package: "institute"),
                .product(name: "Command", package: "swift-arguments"),
                .product(name: "JSON", package: "swift-json"),
            ],
            path: "Tests/Institute Application Tests"
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
