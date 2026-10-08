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
    .package(url: "https://github.com/swift-compositions/swift-agent-skills.git", branch: "main"),
    .package(url: "https://github.com/swift-compositions/swift-arguments.git", branch: "main"),
    .package(url: "https://github.com/swift-atoms/swift-ascii.git", branch: "main"),
    .package(url: "https://github.com/swift-molecules/swift-async-fanout.git", branch: "main"),
    .package(url: "https://github.com/swift-compositions/swift-environment.git", branch: "main"),
    .package(url: "https://github.com/swift-compositions/swift-file-system.git", branch: "main"),
    .package(url: "https://github.com/swift-compositions/swift-github.git", branch: "main"),
    .package(url: "https://github.com/swift-compositions/swift-git.git", branch: "main"),
    .package(url: "https://github.com/swift-compositions/swift-json.git", branch: "main"),
    .package(url: "https://github.com/swift-compositions/swift-kernel.git", branch: "main"),
    .package(url: "https://github.com/swift-compositions/swift-package-manager.git", branch: "main"),
    .package(url: "https://github.com/swift-compositions/swift-posix.git", branch: "main"),
    .package(url: "https://github.com/swift-compositions/swift-process.git", branch: "main"),
    .package(url: "https://github.com/swift-compositions/swift-threads.git", branch: "main"),
    .package(url: "https://github.com/swift-compositions/swift-xcode.git", branch: "main"),
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
    .package(url: "https://github.com/swift-ietf/swift-rfc-3986.git", branch: "main"),
    .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
    .package(url: "https://github.com/swift-atoms/swift-tagged.git", branch: "main"),
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
        .product(name: "Async Fanout", package: "swift-async-fanout"),
        .product(name: "Byte", package: "swift-byte"),
        .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "Git", package: "swift-git"),
        .product(name: "GitHub", package: "swift-github"),
        .product(name: "JSON", package: "swift-json"),
        .product(name: "Kernel", package: "swift-kernel"),
        .product(name: "RFC 3986", package: "swift-rfc-3986"),
        .product(name: "Tagged", package: "swift-tagged"),
      ]
    ),
    .target(
      name: "Institute Inventory",
      dependencies: [
        "Institute Model",
        .product(name: "Byte", package: "swift-byte"),
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "Git", package: "swift-git"),
        .product(name: "GitHub", package: "swift-github"),
        .product(name: "JSON", package: "swift-json"),
        .product(name: "Kernel", package: "swift-kernel"),
        .product(name: "Process", package: "swift-process"),
        .product(name: "Tagged", package: "swift-tagged"),
      ]
    ),
    .target(
      name: "Institute Source Workspace",
      dependencies: [
        "Institute Model",
        .product(name: "Async Fanout", package: "swift-async-fanout"),
        .product(name: "Byte", package: "swift-byte"),
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
        .product(name: "Git", package: "swift-git"),
        .product(name: "JSON", package: "swift-json"),
        "Source Measurement",
        .product(name: "Xcode Workspace", package: "swift-xcode"),
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
    .target(
      name: "Institute Dependency",
      dependencies: [
        "Institute Model",
        "Institute Inventory",
        .product(name: "Async Fanout", package: "swift-async-fanout"),
        .product(name: "Byte", package: "swift-byte"),
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
        .product(name: "Async Fanout", package: "swift-async-fanout"),
        .product(name: "Byte", package: "swift-byte"),
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
        .product(
          name: "Standard Library Extensions",
          package: "swift-standard-library-extensions"
        ),
      ]
    ),
    .target(
      name: "Institute Lint",
      dependencies: [
        "Institute Build Coordinator",
        "Institute Model",
        "Institute Development",
        "Institute Source Policy",
        .product(name: "Async Fanout", package: "swift-async-fanout"),
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
        .product(name: "Async Fanout", package: "swift-async-fanout"),
        .product(name: "Environment", package: "swift-environment"),
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "Git", package: "swift-git"),
        .product(name: "JSON", package: "swift-json"),
        .product(name: "Package Manager", package: "swift-package-manager"),
        .product(name: "Process", package: "swift-process"),
        .product(name: "Tagged", package: "swift-tagged"),
        .product(
          name: "Standard Library Extensions",
          package: "swift-standard-library-extensions"
        ),
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
        .product(name: "Tagged", package: "swift-tagged"),
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
        .product(name: "Async Fanout", package: "swift-async-fanout"),
        .product(name: "Byte", package: "swift-byte"),
        .product(name: "Command", package: "swift-arguments"),
        .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "Git", package: "swift-git"),
        .product(name: "GitHub", package: "swift-github"),
        .product(name: "JSON", package: "swift-json"),
        .product(name: "Package Manager", package: "swift-package-manager"),
        "Source Measurement",
        "Source Repair",
        .product(name: "SPM Standard", package: "swift-spm-standard"),
        .product(name: "Skill Validation", package: "swift-agent-skills"),
        .product(
          name: "Standard Library Extensions",
          package: "swift-standard-library-extensions"
        ),
        .product(name: "Xcode Workspace", package: "swift-xcode"),
        .product(name: "Xcode Workspace Standard", package: "swift-xcode-standard"),
        .product(name: "Tagged", package: "swift-tagged"),
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
        "Institute Source Policy",
        "Institute Model",
        "Source Profile",
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
        .product(name: "Git", package: "swift-git"),
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
