import Lint
import Linter_Rules_Test_Support
import SwiftParser
import Testing

@testable import Institute_Linter_Rule_Manifest

extension `Lint.Rule Tests` {
    @Suite
    struct `untraited partial dependency Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension `Lint.Rule Tests`.`untraited partial dependency Tests` {
    static func observation(
        _ source: Swift::String,
        file: Swift::String = "Package.swift"
    ) -> Lint.Rule.Observation {
        Lint.Rule.`untraited partial dependency`.observe(Lint.Source.parsed(from: source, file: file), .warning)
    }

    static let statement =
        "[untraited partial dependency] [I7]: in a package with a primary target, a target outside the primary "
        + "target's closure takes a product from a package the closure does not reach only under a trait condition,"
}

extension `Lint.Rule Tests`.`untraited partial dependency Tests`.Unit {
    @Test
    func `a dependency one of two products needs is flagged`() {
        let observation = `Lint.Rule Tests`.`untraited partial dependency Tests`.observation(
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
        #expect(observation.findings[0].message.hasPrefix(`Lint.Rule Tests`.`untraited partial dependency Tests`.statement))
        #expect(
            observation.findings[0].message.contains(
                "`Owner Glob` takes `swift-glob` without one, and `Owner` and the targets it reaches do not take `swift-glob`;"
            )
        )
        #expect(observation.findings[0].message.contains("ENABLE_TARGET_BASED_DEPENDENCY_RESOLUTION"))
    }

    @Test
    func `the same dependency behind a trait named for the peer is clean`() {
        let observation = `Lint.Rule Tests`.`untraited partial dependency Tests`.observation(
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
        let observation = `Lint.Rule Tests`.`untraited partial dependency Tests`.observation(
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
    func `a dependency the primary target needs is clean though a slimmer target does without it`() {
        let observation = `Lint.Rule Tests`.`untraited partial dependency Tests`.observation(
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

    @Test
    func `a target no product exposes is judged too`() {
        let observation = `Lint.Rule Tests`.`untraited partial dependency Tests`.observation(
            """
            let package = Package(
                name: "swift-owner",
                products: [.library(name: "Owner", targets: ["Owner"])],
                targets: [
                    .target(name: "Owner"),
                    .target(name: "Owner Glob", dependencies: [.product(name: "Glob", package: "swift-glob")]),
                ]
            )
            """
        )
        #expect(observation.findings.count == 1)
    }
}

extension `Lint.Rule Tests`.`untraited partial dependency Tests`.`Edge Case` {
    @Test
    func `a package without a primary target is inapplicable`() {
        let observation = `Lint.Rule Tests`.`untraited partial dependency Tests`.observation(
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
    func `the primary target is the regular target whose name claims the package's concept`() {
        let graph = ManifestGraph(
            tree: Parser.parse(
                source: """
                    let package = Package(
                        name: "swift-memory-allocation",
                        targets: [.macro(name: "MemoryAllocation"), .target(name: "Memory Allocation")]
                    )
                    """
            )
        )
        #expect(graph.primaryTarget?.name == "Memory Allocation")
        #expect(graph.primaryTarget?.kind == .regular)
    }

    @Test
    func `a Test Support target that reaches only the primary target is clean and applicable`() {
        let observation = `Lint.Rule Tests`.`untraited partial dependency Tests`.observation(
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
        #expect(observation.applicability == .applicable)
    }

    @Test
    func `a dependency of Test Support is judged, and one of a test target is not`() {
        let observation = `Lint.Rule Tests`.`untraited partial dependency Tests`.observation(
            """
            let package = Package(
                name: "swift-owner",
                products: [
                    .library(name: "Owner", targets: ["Owner"]),
                    .library(name: "Owner Test Support", targets: ["Owner Test Support"]),
                ],
                targets: [
                    .target(name: "Owner"),
                    .target(
                        name: "Owner Test Support",
                        dependencies: [
                            .target(name: "Owner"),
                            .product(name: "Testing Support", package: "swift-testing-support"),
                        ]
                    ),
                    .testTarget(
                        name: "Owner Tests",
                        dependencies: [.product(name: "Fixtures", package: "swift-fixtures")]
                    ),
                ]
            )
            """
        )
        #expect(observation.findings.count == 1)
        #expect(observation.findings[0].message.contains("`Owner Test Support` takes `swift-testing-support`"))
    }

    @Test
    func `a Foundation Integration target is not exempt`() {
        let observation = `Lint.Rule Tests`.`untraited partial dependency Tests`.observation(
            """
            let package = Package(
                name: "swift-owner",
                products: [.library(name: "Owner", targets: ["Owner"])],
                targets: [
                    .target(name: "Owner"),
                    .target(
                        name: "Owner Foundation Integration",
                        dependencies: ["Owner", .product(name: "URI", package: "swift-uri")]
                    ),
                ]
            )
            """
        )
        #expect(observation.findings.count == 1)
    }

    @Test
    func `a platform condition is not a trait gate`() {
        let observation = `Lint.Rule Tests`.`untraited partial dependency Tests`.observation(
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
        let observation = `Lint.Rule Tests`.`untraited partial dependency Tests`.observation(
            "let dependency = Target.Dependency.product(name: \"Glob\", package: \"swift-glob\")",
            file: "Sources/Fixture/Fixture.swift"
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }

    @Test
    func `a target gated by two traits, a trait not named for its one peer, and a shared trait are each found`() {
        let observation = `Lint.Rule Tests`.`untraited partial dependency Tests`.observation(
            """
            let package = Package(
                name: "swift-owner",
                products: [.library(name: "Owner", targets: ["Owner"])],
                traits: [.trait(name: "Glob"), .trait(name: "Span"), .trait(name: "Extras")],
                targets: [
                    .target(name: "Owner"),
                    .target(
                        name: "Owner Glob",
                        dependencies: [
                            .product(name: "Glob", package: "swift-glob", condition: .when(traits: ["Glob"])),
                            .product(name: "Span", package: "swift-span", condition: .when(traits: ["Span"])),
                        ]
                    ),
                    .target(
                        name: "Owner Path",
                        dependencies: [.product(name: "Path", package: "swift-path", condition: .when(traits: ["Extras"]))]
                    ),
                    .target(
                        name: "Owner Text",
                        dependencies: [.product(name: "Text", package: "swift-text", condition: .when(traits: ["Glob"]))]
                    ),
                ]
            )
            """
        )
        let messages = observation.findings.map(\.message)
        #expect(messages.count == 4)
        #expect(messages.contains { $0.contains("`Owner Glob` is gated by `Glob`, `Span`; one trait gates one target.") })
        #expect(messages.contains { $0.contains("`Owner Path` is glue to `swift-path` alone, so its trait is named for `swift-path`, not `Extras`.") })
        #expect(messages.contains { $0.contains("`Owner Text` is glue to `swift-text` alone") })
        #expect(messages.contains { $0.contains("`Owner Text` and `Owner Glob` share the trait `Glob`") })
    }

    @Test
    func `a macro's declarations, its macro target and its implementation share one trait`() {
        let observation = `Lint.Rule Tests`.`untraited partial dependency Tests`.observation(
            """
            let package = Package(
                name: "swift-owner",
                products: [.library(name: "Owner", targets: ["Owner"])],
                traits: [.trait(name: "Syntax")],
                targets: [
                    .target(name: "Owner"),
                    .target(
                        name: "Owner Macro",
                        dependencies: [
                            "Owner Macro Plugin",
                            .product(name: "SwiftSyntax", package: "swift-syntax", condition: .when(traits: ["Syntax"])),
                        ]
                    ),
                    .macro(
                        name: "Owner Macro Plugin",
                        dependencies: [
                            .product(name: "SwiftSyntaxMacros", package: "swift-syntax", condition: .when(traits: ["Syntax"]))
                        ]
                    ),
                ]
            )
            """
        )
        #expect(observation.findings.isEmpty)
    }
}

extension `Lint.Rule Tests`.`untraited partial dependency Tests`.Integration {
    @Test
    func `typed manifest accessors resolve and each target's partial package is reported once`() {
        let observation = `Lint.Rule Tests`.`untraited partial dependency Tests`.observation(
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
                    .target(name: .ownerGlob, dependencies: [.owner, .glob, .threads, .threads]),
                ]
            )
            """
        )
        #expect(observation.coverage == .measured)
        #expect(observation.findings.count == 3)
        #expect(observation.findings.contains { $0.message.contains("`Owner Kernel` takes `swift-threads` without one") })
        #expect(observation.findings.contains { $0.message.contains("`Owner Glob` takes `swift-glob` without one") })
        #expect(observation.findings.contains { $0.message.contains("`Owner Glob` takes `swift-threads` without one") })
    }

    @Test
    func `while Issues#123 is open, a target whose source is gated by its trait may take its product unconditionally`()
        throws
    {
        let manifest = """
            let package = Package(
                name: "swift-owner",
                products: [.library(name: "Owner", targets: ["Owner"])],
                traits: [.trait(name: "Glob")],
                targets: [
                    .target(name: "Owner"),
                    .target(name: "Owner Glob", dependencies: ["Owner", .product(name: "Glob", package: "swift-glob")]),
                    .target(name: "Owner Path", dependencies: ["Owner", .product(name: "Path", package: "swift-path")]),
                ]
            )
            """
        let fixture = try Lint.Source.Fixture(files: [
            "Package.swift": manifest,
            "Sources/Owner/Owner.swift": "public enum Owner {}",
            "Sources/Owner Glob/Owner.Glob.swift": "public import Owner\n#if Glob\nextension Owner {\n    public struct Glob {}\n}\n#endif",
            "Sources/Owner Glob/exports.swift": "public import Owner",
            "Sources/Owner Path/Owner.Path.swift": "#if os(macOS)\nextension Owner {\n    public struct Path {}\n}\n#endif",
        ])
        let observation = Lint.Rule.`untraited partial dependency`.observe(fixture.parsed("Package.swift"), .warning)
        #expect(observation.findings.count == 1)
        #expect(observation.findings.first?.message.contains("`Owner Path` takes `swift-path`") == true)
    }
}
