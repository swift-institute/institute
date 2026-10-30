import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Manifest

extension Lint.Rule {
    @Suite
    struct `untraited partial dependency Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`untraited partial dependency Tests` {
    static func observation(
        _ source: Swift::String,
        file: Swift::String = "Package.swift"
    ) -> Lint.Rule.Observation {
        Lint.Rule.`untraited partial dependency`.observe(Lint.Source.parsed(from: source, file: file), .warning)
    }
}

extension Lint.Rule.`untraited partial dependency Tests`.Unit {
    @Test
    func `a dependency one of two products needs is flagged`() {
        let observation = Lint.Rule.`untraited partial dependency Tests`.observation(
            """
            let package = Package(
                name: "swift-owner",
                products: [
                    .library(name: "Owner", targets: ["Owner"]),
                    .library(name: "Owner Glob", targets: ["Owner Glob"]),
                ],
                targets: [
                    .target(name: "Owner"),
                    .target(
                        name: "Owner Glob",
                        dependencies: [
                            .target(name: "Owner"),
                            .product(name: "Glob", package: "swift-glob"),
                        ]
                    ),
                ]
            )
            """
        )
        #expect(observation.coverage == .measured)
        #expect(observation.findings.count == 1)
        #expect(
            observation.findings[0].message.hasPrefix(
                "[untraited partial dependency] [PACKAGE-TRAIT-GATED-DEPENDENCY]: `swift-glob` is needed by "
                    + "`Owner Glob` but not by `Owner`;"
            )
        )
        #expect(observation.findings[0].message.contains("ENABLE_TARGET_BASED_DEPENDENCY_RESOLUTION"))
    }

    @Test
    func `the same dependency behind a trait is clean`() {
        let observation = Lint.Rule.`untraited partial dependency Tests`.observation(
            """
            let package = Package(
                name: "swift-owner",
                products: [
                    .library(name: "Owner", targets: ["Owner"]),
                    .library(name: "Owner Glob", targets: ["Owner Glob"]),
                ],
                traits: [.trait(name: "Glob")],
                targets: [
                    .target(name: "Owner"),
                    .target(
                        name: "Owner Glob",
                        dependencies: [
                            .target(name: "Owner"),
                            .product(name: "Glob", package: "swift-glob", condition: .when(traits: ["Glob"])),
                        ]
                    ),
                ]
            )
            """
        )
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `a dependency every product reaches through a shared core is clean`() {
        let observation = Lint.Rule.`untraited partial dependency Tests`.observation(
            """
            let package = Package(
                name: "swift-owner",
                products: [
                    .library(name: "Owner", targets: ["Owner"]),
                    .library(name: "Owner Glob", targets: ["Owner Glob"]),
                ],
                targets: [
                    .target(name: "Owner Core", dependencies: [.product(name: "Span", package: "swift-span")]),
                    .target(name: "Owner", dependencies: ["Owner Core"]),
                    .target(name: "Owner Glob", dependencies: [.byName(name: "Owner Core")]),
                ]
            )
            """
        )
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `a dependency the primary product needs is clean though a slimmer product does without it`() {
        let observation = Lint.Rule.`untraited partial dependency Tests`.observation(
            """
            let package = Package(
                name: "swift-owner",
                products: [
                    .library(name: "Owner", targets: ["Owner"]),
                    .library(name: "Owner Core", targets: ["Owner Core"]),
                ],
                targets: [
                    .target(name: "Owner Core"),
                    .target(
                        name: "Owner",
                        dependencies: [
                            .target(name: "Owner Core"),
                            .product(name: "Span", package: "swift-span"),
                        ]
                    ),
                ]
            )
            """
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability != .inapplicable)
    }
}

extension Lint.Rule.`untraited partial dependency Tests`.`Edge Case` {
    @Test
    func `a package without a product named after it is inapplicable`() {
        let observation = Lint.Rule.`untraited partial dependency Tests`.observation(
            """
            let package = Package(
                name: "swift-owner",
                products: [
                    .library(name: "Owner Kernel", targets: ["Owner Kernel"]),
                    .library(name: "Owner Glob", targets: ["Owner Glob"]),
                ],
                targets: [
                    .target(name: "Owner Kernel"),
                    .target(name: "Owner Glob", dependencies: [.product(name: "Glob", package: "swift-glob")]),
                ]
            )
            """
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }

    @Test
    func `the primary product matches without case, spaces, hyphens or the swift- prefix`() {
        #expect(manifestUntraitedPartialDependencyFolded("swift-memory-allocation", droppingPrefix: "swift-") == "memoryallocation")
        #expect(manifestUntraitedPartialDependencyFolded("Memory Allocation") == "memoryallocation")
        #expect(manifestUntraitedPartialDependencyFolded("swift-iso-32000", droppingPrefix: "swift-") == "iso32000")
        #expect(manifestUntraitedPartialDependencyFolded("ISO 32000") == "iso32000")
    }

    @Test
    func `a single main product with Test Support is inapplicable`() {
        let observation = Lint.Rule.`untraited partial dependency Tests`.observation(
            """
            let package = Package(
                name: "swift-owner",
                products: [
                    .library(name: "Owner", targets: ["Owner"]),
                    .library(name: "Owner Test Support", targets: ["Owner Test Support"]),
                ],
                targets: [
                    .target(name: "Owner", dependencies: [.product(name: "Span", package: "swift-span")]),
                    .target(name: "Owner Test Support", dependencies: [.target(name: "Owner")]),
                ]
            )
            """
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }

    @Test
    func `a dependency only Test Support and test targets use is clean`() {
        let observation = Lint.Rule.`untraited partial dependency Tests`.observation(
            """
            let package = Package(
                name: "swift-owner",
                products: [
                    .library(name: "Owner", targets: ["Owner"]),
                    .library(name: "Owner Glob", targets: ["Owner Glob"]),
                    .library(name: "Owner Test Support", targets: ["Owner Test Support"]),
                ],
                targets: [
                    .target(name: "Owner"),
                    .target(name: "Owner Glob", dependencies: [.target(name: "Owner")]),
                    .target(
                        name: "Owner Test Support",
                        dependencies: [
                            .target(name: "Owner"),
                            .product(name: "Testing Support", package: "swift-testing-support"),
                        ]
                    ),
                    .testTarget(
                        name: "Owner Glob Tests",
                        dependencies: [.product(name: "Fixtures", package: "swift-fixtures")]
                    ),
                ]
            )
            """
        )
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `a platform condition is not a trait gate`() {
        let observation = Lint.Rule.`untraited partial dependency Tests`.observation(
            """
            let package = Package(
                name: "swift-owner",
                products: [
                    .library(name: "Owner", targets: ["Owner"]),
                    .library(name: "Owner Glob", targets: ["Owner Glob"]),
                ],
                targets: [
                    .target(name: "Owner"),
                    .target(
                        name: "Owner Glob",
                        dependencies: [
                            .product(name: "Glob", package: "swift-glob", condition: .when(platforms: [.linux])),
                        ]
                    ),
                ]
            )
            """
        )
        #expect(observation.findings.count == 1)
    }

    @Test
    func `non-manifest files are inapplicable`() {
        let observation = Lint.Rule.`untraited partial dependency Tests`.observation(
            "let dependency = Target.Dependency.product(name: \"Glob\", package: \"swift-glob\")",
            file: "Sources/Fixture/Fixture.swift"
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }
}

extension Lint.Rule.`untraited partial dependency Tests`.Integration {
    @Test
    func `typed manifest accessors resolve and each partial package is reported once`() {
        let observation = Lint.Rule.`untraited partial dependency Tests`.observation(
            """
            extension String {
                static let owner: Self = "Owner"
                static let ownerKernel: Self = "Owner Kernel"
                static let ownerGlob: Self = "Owner Glob"
            }
            extension Target.Dependency {
                static var owner: Self { .target(name: .owner) }
                static var glob: Self { .product(name: "Glob", package: "swift-glob") }
                static var threads: Self { .product(name: "Threads", package: "swift-threads") }
            }
            let package = Package(
                name: "swift-owner",
                products: [
                    .library(name: .owner, targets: [.owner]),
                    .library(name: .ownerKernel, targets: [.ownerKernel]),
                    .library(name: .ownerGlob, targets: [.ownerGlob]),
                ],
                targets: [
                    .target(name: .owner),
                    .target(name: .ownerKernel, dependencies: [.owner, .threads]),
                    .target(name: .ownerGlob, dependencies: [.owner, .glob, .threads]),
                ]
            )
            """
        )
        #expect(observation.coverage == .measured)
        #expect(observation.findings.count == 2)
        #expect(observation.findings.contains { $0.message.contains("`swift-glob` is needed by `Owner Glob` but not by `Owner`, `Owner Kernel`;") })
        #expect(
            observation.findings.contains {
                $0.message.contains("`swift-threads` is needed by `Owner Kernel`, `Owner Glob` but not by `Owner`;")
            }
        )
    }
}
