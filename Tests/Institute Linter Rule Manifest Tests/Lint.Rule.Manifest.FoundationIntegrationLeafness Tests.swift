// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-institute-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-institute-linter-rules project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Lint
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Institute_Linter_Rule_Manifest

extension Lint.Rule {
    @Suite
    struct `foundation integration leaf target Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct Negative {}
    }
}

extension Lint.Rule.`foundation integration leaf target Tests` {
    static func findings(
        source: Swift::String,
        file: Swift::String = "Package.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`foundation integration leaf target`.observe(parsed, .warning).findings
    }

    static func observation(source: Swift::String) -> Lint.Rule.Observation {
        let parsed = Lint.Source.parsed(from: source, file: "Package.swift")
        return Lint.Rule.`foundation integration leaf target`.observe(parsed, .warning)
    }
}

extension Lint.Rule.`foundation integration leaf target Tests`.Negative {
    @Test
    func `sanctioned shape - own leaf product, no incoming edge - is NOT flagged`() {
        // Reference sanctioned shape: swift-structured-queries'
        // `Structured Queries Foundation Integration` — its own
        // `.library` product, and no other target lists it as a
        // dependency (it may depend OUTWARD on the core target; that's
        // fine — only incoming edges are checked).
        let source = """
            let package = Package(
              name: "swift-structured-queries",
              products: [
                .library(
                  name: "Structured Queries",
                  targets: ["Structured Queries"]
                ),
                .library(
                  name: "Structured Queries Foundation Integration",
                  targets: ["Structured Queries Foundation Integration"]
                ),
              ],
              targets: [
                .target(
                  name: "Structured Queries",
                  dependencies: []
                ),
                .target(
                  name: "Structured Queries Foundation Integration",
                  dependencies: [
                    "Structured Queries",
                  ]
                ),
              ]
            )
            """
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(source: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `a singleton executable Foundation Integration product is NOT flagged`() {
        let source = """
            let package = Package(
              name: "x",
              products: [
                .library(name: "X", targets: ["X"]),
                .executable(
                  name: "x-foundation-integration",
                  targets: ["X Foundation Integration"]
                ),
              ],
              targets: [
                .target(name: "X", dependencies: []),
                .executableTarget(
                  name: "X Foundation Integration",
                  dependencies: ["X"]
                ),
              ]
            )
            """
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(source: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-manifest file is NOT scanned`() {
        let source = """
            .target(
                name: "X Foundation Integration",
                dependencies: []
            )
            """
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(
            source: source,
            file: "Sources/X/Notes.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `target not named Foundation Integration is NOT flagged regardless of shape`() {
        let source = """
            let package = Package(
              name: "x",
              products: [
                .library(name: "Core", targets: ["Core", "Support"])
              ],
              targets: [
                .target(name: "Core", dependencies: []),
                .target(name: "Support", dependencies: ["Core"]),
              ]
            )
            """
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(source: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `empty file produces no findings`() {
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(source: "")
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`foundation integration leaf target Tests`.Unit {
    @Test
    func `Foundation Integration target folded into a shared product is flagged`() {
        // Condition (b) violated: not a leaf product of its own — bundled
        // into a product alongside the core target.
        let source = """
            let package = Package(
              name: "x",
              products: [
                .library(
                  name: "X",
                  targets: ["X", "X Foundation Integration"]
                )
              ],
              targets: [
                .target(name: "X", dependencies: []),
                .target(name: "X Foundation Integration", dependencies: ["X"]),
              ]
            )
            """
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(source: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "foundation integration leaf target")
        }
    }

    @Test
    func `Foundation Integration target folded into a shared executable product is flagged`() {
        let source = """
            let package = Package(
              name: "x",
              products: [
                .executable(
                  name: "x",
                  targets: ["X", "X Foundation Integration"]
                ),
              ],
              targets: [
                .executableTarget(name: "X", dependencies: []),
                .executableTarget(name: "X Foundation Integration", dependencies: ["X"]),
              ]
            )
            """
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(source: source)
        #expect(findings.count == 1)
    }

    @Test
    func `a non Foundation Integration executable product does not satisfy the leaf product`() {
        let source = """
            let package = Package(
              name: "x",
              products: [
                .executable(name: "x", targets: ["X"]),
              ],
              targets: [
                .executableTarget(name: "X", dependencies: []),
                .executableTarget(name: "X Foundation Integration", dependencies: ["X"]),
              ]
            )
            """
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(source: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Foundation Integration target with no product at all is flagged`() {
        let source = """
            let package = Package(
              name: "x",
              products: [
                .library(name: "X", targets: ["X"])
              ],
              targets: [
                .target(name: "X", dependencies: []),
                .target(name: "X Foundation Integration", dependencies: ["X"]),
              ]
            )
            """
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(source: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Foundation Integration target depended on by a core target is flagged`() {
        // Condition (c) violated: a core target depends on it, even
        // though it IS its own leaf product.
        let source = """
            let package = Package(
              name: "x",
              products: [
                .library(name: "X", targets: ["X"]),
                .library(name: "X Foundation Integration", targets: ["X Foundation Integration"]),
              ],
              targets: [
                .target(name: "X", dependencies: ["X Foundation Integration"]),
                .target(name: "X Foundation Integration", dependencies: []),
              ]
            )
            """
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(source: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Foundation Integration executable depended on by a core target is flagged`() {
        let source = """
            let package = Package(
              name: "x",
              products: [
                .library(name: "X", targets: ["X"]),
                .executable(
                  name: "x-foundation-integration",
                  targets: ["X Foundation Integration"]
                ),
              ],
              targets: [
                .target(name: "X", dependencies: ["X Foundation Integration"]),
                .executableTarget(name: "X Foundation Integration", dependencies: []),
              ]
            )
            """
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(source: source)
        #expect(findings.count == 1)
    }

    @Test
    func `incoming edge via the dot-target spelling is flagged`() {
        let source = """
            let package = Package(
              name: "x",
              products: [
                .library(name: "X", targets: ["X"]),
                .library(name: "X Foundation Integration", targets: ["X Foundation Integration"]),
              ],
              targets: [
                .target(name: "X", dependencies: [.target(name: "X Foundation Integration")]),
                .target(name: "X Foundation Integration", dependencies: []),
              ]
            )
            """
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(source: source)
        #expect(findings.count == 1)
    }

    @Test
    func `incoming edge from a Test Support target is flagged`() {
        // The doctrinal condition names "any other target" — core,
        // Support, Test Support, or test target — not only the core
        // target.
        let source = """
            let package = Package(
              name: "x",
              products: [
                .library(name: "X", targets: ["X"]),
                .library(name: "X Foundation Integration", targets: ["X Foundation Integration"]),
              ],
              targets: [
                .target(name: "X", dependencies: []),
                .target(name: "X Foundation Integration", dependencies: ["X"]),
                .target(
                  name: "X Test Support",
                  dependencies: ["X Foundation Integration"]
                ),
              ]
            )
            """
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(source: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`foundation integration leaf target Tests`.`Edge Case` {
    @Test
    func `computed product target list is unmeasured`() {
        let source = """
            let package = Package(
              name: "x",
              products: [.library(name: "X Foundation Integration", targets: targets)],
              targets: [.target(name: "X Foundation Integration")]
            )
            """
        let observation = Lint.Rule.`foundation integration leaf target Tests`.observation(
            source: source
        )
        guard case .unmeasured = observation.coverage else {
            Issue.record("computed product target list was accepted as measured")
            return
        }
    }

    @Test
    func `Foundation Integration target that is both non-leaf and depended-on reports once`() {
        let source = """
            let package = Package(
              name: "x",
              products: [
                .library(name: "X", targets: ["X", "X Foundation Integration"])
              ],
              targets: [
                .target(name: "X", dependencies: ["X Foundation Integration"]),
                .target(name: "X Foundation Integration", dependencies: []),
              ]
            )
            """
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(source: source)
        #expect(findings.count == 1)
    }

    @Test
    func `two independent Foundation Integration targets are tracked independently`() {
        let source = """
            let package = Package(
              name: "x",
              products: [
                .library(name: "Good", targets: ["Good"]),
                .library(
                  name: "Good Foundation Integration",
                  targets: ["Good Foundation Integration"]
                ),
                .library(name: "Bad", targets: ["Bad"]),
              ],
              targets: [
                .target(name: "Good", dependencies: []),
                .target(name: "Good Foundation Integration", dependencies: ["Good"]),
                .target(name: "Bad", dependencies: []),
                .target(name: "Bad Foundation Integration", dependencies: ["Bad"]),
              ]
            )
            """
        let findings = Lint.Rule.`foundation integration leaf target Tests`.findings(source: source)
        #expect(findings.count == 1)
    }
}
