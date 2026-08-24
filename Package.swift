// swift-tools-version: 6.4

import PackageDescription

let package = Package(
  name: "institute",
  platforms: [
    .macOS("27"),
    .iOS("27"),
    .tvOS("27"),
    .watchOS("27"),
    .visionOS("27"),
  ],
  products: [
    .library(
      name: "Institute Build Coordinator",
      targets: ["Institute Build Coordinator"]
    ),
    .library(
      name: "Institute Model",
      targets: ["Institute Model"]
    ),
    .library(
      name: "Institute Inventory",
      targets: ["Institute Inventory"]
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
    .library(
      name: "Institute Dependency",
      targets: ["Institute Dependency"]
    ),
    .library(
      name: "Institute Development",
      targets: ["Institute Development"]
    ),
    .library(
      name: "Institute Lint",
      targets: ["Institute Lint"]
    ),
    .library(
      name: "Institute Pages",
      targets: ["Institute Pages"]
    ),
    .library(
      name: "Institute Doctor",
      targets: ["Institute Doctor"]
    ),
    .library(
      name: "Institute Conversion",
      targets: ["Institute Conversion"]
    ),
    .library(
      name: "Institute Instruments",
      targets: ["Institute Instruments"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-agent-skills.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-arguments.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-ascii.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-async.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-environment.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-file-system.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-github.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-git.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-json.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-kernel.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-package-manager.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-posix.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-process.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-threads.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-xcode.git", branch: "main"),
    .package(url: "https://github.com/swift-standards/swift-xcode-standard.git", branch: "main"),
    .package(url: "https://github.com/swift-foundations/swift-source.git", branch: "main"),
    .package(
      url: "https://github.com/swift-primitives/swift-linter-primitives.git",
      branch: "main"
    ),
    .package(
      url: "https://github.com/swift-foundations/swift-institute-linter-rules.git",
      branch: "main"
    ),
    .package(
      url: "https://github.com/swift-primitives/swift-primitives-linter-rules.git",
      branch: "main"
    ),
    .package(
      url: "https://github.com/swift-standards/swift-standards-linter-rules.git",
      branch: "main"
    ),
    .package(url: "https://github.com/swift-ietf/swift-rfc-3986.git", branch: "main"),
    .package(url: "https://github.com/swift-primitives/swift-byte-primitives.git", branch: "main"),
    .package(url: "https://github.com/swift-standards/swift-fips-180-4.git", branch: "main"),
    .package(url: "https://github.com/swift-standards/swift-github-standard.git", branch: "main"),
    .package(url: "https://github.com/swift-standards/swift-spm-standard.git", branch: "main"),
    .package(
      url: "https://github.com/swift-primitives/swift-standard-library-extensions.git",
      branch: "main"
    ),
  ],
  targets: [
    .target(
      name: "Institute Build Coordinator",
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
        .product(name: "Async Fanout", package: "swift-async"),
        .product(name: "Byte Primitives", package: "swift-byte-primitives"),
        .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "Git", package: "swift-git"),
        .product(name: "GitHub", package: "swift-github"),
        .product(name: "JSON", package: "swift-json"),
        .product(name: "Kernel", package: "swift-kernel"),
        .product(name: "RFC 3986", package: "swift-rfc-3986"),
      ]
    ),
    .target(
      name: "Institute Inventory",
      dependencies: [
        "Institute Model",
        .product(name: "Byte Primitives", package: "swift-byte-primitives"),
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "Git", package: "swift-git"),
        .product(name: "GitHub", package: "swift-github"),
        .product(name: "JSON", package: "swift-json"),
        .product(name: "Kernel", package: "swift-kernel"),
        .product(name: "Process", package: "swift-process"),
      ]
    ),
    .target(
      name: "Institute Source Workspace",
      dependencies: [
        "Institute Model",
        .product(name: "Async Fanout", package: "swift-async"),
        .product(name: "Byte Primitives", package: "swift-byte-primitives"),
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
        .product(name: "Git", package: "swift-git"),
        .product(name: "JSON", package: "swift-json"),
        .product(name: "Source Measurement", package: "swift-source"),
        .product(name: "Xcode Workspace", package: "swift-xcode"),
      ]
    ),
    .target(
      name: "Institute Source Policy",
      dependencies: [
        "Institute Model",
        .product(name: "Byte Primitives", package: "swift-byte-primitives"),
        .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
        .product(name: "Source Profile", package: "swift-source"),
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
        .product(name: "Byte Primitives", package: "swift-byte-primitives"),
        .product(
          name: "Byte Primitives Standard Library Integration",
          package: "swift-byte-primitives"
        ),
        .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
      ]
    ),
    .target(
      name: "Institute CI Workflow",
      dependencies: [
        "Institute CI Model",
        "Institute Model",
      ]
    ),
    .target(
      name: "Institute CI Inventory",
      dependencies: [
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
        .product(name: "Byte Primitives", package: "swift-byte-primitives"),
        .product(
          name: "Byte Primitives Standard Library Integration",
          package: "swift-byte-primitives"
        ),
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
        .product(name: "Byte Primitives", package: "swift-byte-primitives"),
        .product(
          name: "Byte Primitives Standard Library Integration",
          package: "swift-byte-primitives"
        ),
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
        .product(name: "Linter Primitives", package: "swift-linter-primitives"),
        .product(name: "Source Measurement", package: "swift-source"),
        .product(name: "Source Profile", package: "swift-source"),
      ]
    ),
    .target(
      name: "Institute Source",
      dependencies: [
        "Institute Model",
        "Institute Source Policy",
        "Institute Source Profile",
        "Institute Source Workspace",
        .product(name: "Async Fanout", package: "swift-async"),
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
        .product(name: "Process", package: "swift-process"),
        .product(name: "Source Execution", package: "swift-source"),
        .product(name: "Source Measurement", package: "swift-source"),
        .product(name: "Source Profile", package: "swift-source"),
        .product(name: "Source Repair", package: "swift-source"),
        .product(name: "Source Linter", package: "swift-source"),
        .product(name: "Source Report", package: "swift-source"),
        .product(name: "Source Swift Format", package: "swift-source"),
        .product(name: "Thread Pool", package: "swift-threads"),
      ]
    ),
    .target(
      name: "Institute Dependency",
      dependencies: [
        "Institute Model",
        "Institute Inventory",
        .product(name: "Async Fanout", package: "swift-async"),
        .product(name: "Byte Primitives", package: "swift-byte-primitives"),
        .product(
          name: "Byte Primitives Standard Library Integration",
          package: "swift-byte-primitives"
        ),
        .product(name: "Command", package: "swift-arguments"),
        .product(name: "GitHub", package: "swift-github"),
        .product(name: "JSON", package: "swift-json"),
        .product(name: "SPM Standard", package: "swift-spm-standard"),
      ]
    ),
    .target(
      name: "Institute Development",
      dependencies: [
        "Institute Build Coordinator",
        "Institute Model",
        "Institute Inventory",
        "Institute Source Workspace",
        .product(name: "Async Fanout", package: "swift-async"),
        .product(name: "Byte Primitives", package: "swift-byte-primitives"),
        .product(name: "Command", package: "swift-arguments"),
        .product(name: "Environment", package: "swift-environment"),
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
        .product(name: "Git", package: "swift-git"),
        .product(name: "JSON", package: "swift-json"),
        // TEMPORARY (institute#10): exec-replace has no cross-platform
        // owner yet — swift-process's `Process` exposes Spawn and Exit
        // only. Route through `Process` once it exposes the replace
        // operation behind its platform conditioning; until then the
        // substrate edge is conditioned off the Windows graph.
        .product(
          name: "POSIX Kernel Process",
          package: "swift-posix",
          condition: .when(platforms: [
            .macOS, .iOS, .tvOS, .watchOS, .visionOS, .linux,
          ])
        ),
        .product(name: "Package Manager", package: "swift-package-manager"),
        .product(name: "Process", package: "swift-process"),
        .product(name: "RFC 3986", package: "swift-rfc-3986"),
        .product(name: "SPM Standard", package: "swift-spm-standard"),
        .product(name: "Skill Validation", package: "swift-agent-skills"),
        .product(name: "Xcode Scheme", package: "swift-xcode"),
        .product(name: "Xcode Workspace", package: "swift-xcode"),
      ]
    ),
    .target(
      name: "Institute Lint",
      dependencies: [
        "Institute Build Coordinator",
        "Institute Model",
        "Institute Development",
        .product(name: "Async Fanout", package: "swift-async"),
        .product(name: "Environment", package: "swift-environment"),
        .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "Git", package: "swift-git"),
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
      name: "Institute Pages",
      dependencies: [
        "Institute Model",
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "JSON", package: "swift-json"),
      ]
    ),
    .target(
      name: "Institute Doctor",
      dependencies: [
        "Institute Model",
        "Institute Inventory",
        "Institute Pages",
        "Institute Development",
        "Institute Lint",
        "Institute Source",
        .product(name: "Async Fanout", package: "swift-async"),
        .product(name: "Environment", package: "swift-environment"),
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "Git", package: "swift-git"),
        .product(name: "JSON", package: "swift-json"),
        .product(name: "Package Manager", package: "swift-package-manager"),
        .product(name: "Process", package: "swift-process"),
      ]
    ),
    .target(
      name: "Institute Conversion",
      dependencies: [
        "Institute Model",
        "Institute Pages",
        "Institute Doctor",
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "JSON", package: "swift-json"),
      ]
    ),
    .target(
      name: "Institute Instruments",
      dependencies: [
        "Institute Build Coordinator",
        "Institute Model",
        "Institute Inventory",
        "Institute Development",
        "Institute Doctor",
        "Institute Lint",
        "Institute Source",
        .product(name: "Command", package: "swift-arguments"),
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "Git", package: "swift-git"),
        .product(name: "GitHub", package: "swift-github"),
        .product(name: "JSON", package: "swift-json"),
        .product(name: "SPM Standard", package: "swift-spm-standard"),
      ]
    ),
    .testTarget(
      name: "Institute Tests",
      dependencies: [
        "Institute Build Coordinator",
        "Institute Model",
        "Institute Inventory",
        "Institute Dependency",
        "Institute Development",
        "Institute Source",
        "Institute Source Policy",
        "Institute Source Profile",
        "Institute Source Workspace",
        "Institute Lint",
        "Institute Pages",
        "Institute Doctor",
        "Institute Conversion",
        "Institute Instruments",
        .product(name: "Async Fanout", package: "swift-async"),
        .product(name: "Byte Primitives", package: "swift-byte-primitives"),
        .product(
          name: "Byte Primitives Standard Library Integration",
          package: "swift-byte-primitives"
        ),
        .product(name: "Command", package: "swift-arguments"),
        .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "Git", package: "swift-git"),
        .product(name: "GitHub", package: "swift-github"),
        .product(name: "JSON", package: "swift-json"),
        .product(name: "Package Manager", package: "swift-package-manager"),
        .product(name: "Source Measurement", package: "swift-source"),
        .product(name: "Source Repair", package: "swift-source"),
        .product(name: "SPM Standard", package: "swift-spm-standard"),
        .product(name: "Skill Validation", package: "swift-agent-skills"),
        .product(
          name: "Standard Library Extensions",
          package: "swift-standard-library-extensions"
        ),
        .product(name: "Xcode Workspace", package: "swift-xcode"),
        .product(name: "Xcode Workspace Standard", package: "swift-xcode-standard"),
      ],
      path: "Tests/Institute Tests"
    ),
    .testTarget(
      name: "Institute Instruments Tests",
      dependencies: [
        "Institute Instruments",
        "Institute Model",
        .product(name: "JSON", package: "swift-json"),
        .product(name: "SPM Standard", package: "swift-spm-standard"),
      ],
      path: "Tests/Institute Instruments Tests"
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
        "Institute CI Model",
        "Institute CI Workflow",
      ]
    ),
    .testTarget(
      name: "Institute Source Policy Tests",
      dependencies: [
        "Institute Source Policy",
        "Institute Model",
        .product(name: "Source Profile", package: "swift-source"),
      ]
    ),
    .testTarget(
      name: "Institute CI Inventory Tests",
      dependencies: ["Institute CI Inventory"],
      exclude: ["Fixtures"]
    ),
    .testTarget(
      name: "Institute CI Validation Tests",
      dependencies: [
        "Institute CI Inventory",
        "Institute CI Validation",
        .product(name: "Process", package: "swift-process"),
      ],
      exclude: ["Fixtures"]
    ),
    .testTarget(
      name: "Institute Development Tests",
      dependencies: [
        "Institute Development",
        "Institute Model",
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "JSON", package: "swift-json"),
        .product(name: "Package Manager", package: "swift-package-manager"),
        .product(name: "SPM Standard", package: "swift-spm-standard"),
        "Institute Build Coordinator",
      ],
      path: "Tests/Institute Development Tests",
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
