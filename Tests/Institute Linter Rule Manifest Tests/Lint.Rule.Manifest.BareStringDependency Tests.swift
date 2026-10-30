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
    struct `bare string dependency Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`bare string dependency Tests` {
    static func findings(
        source: Swift::String,
        file: Swift::String = "Package.swift"
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`bare string dependency`.observe(parsed, .warning).findings
    }

    static func observation(
        source: Swift::String,
        file: Swift::String = "Package.swift"
    ) -> Lint.Rule.Observation {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`bare string dependency`.observe(parsed, .warning)
    }
}

extension Lint.Rule.`bare string dependency Tests`.Unit {
    @Test
    func `bare string in a target dependencies array is flagged`() {
        let source = """
            let package = Package(
              targets: [
                .target(
                  name: "Consumer",
                  dependencies: ["Owner"]
                )
              ]
            )
            """
        let findings = Lint.Rule.`bare string dependency Tests`.findings(source: source)
        #expect(findings.count == 1)
        #expect(findings.first?.identifier == "bare string dependency")
        #expect(findings.first?.severity == .warning)
    }

    @Test
    func `typed accessors are permitted`() {
        let source = """
            let package = Package(
              targets: [
                .target(
                  name: "Consumer",
                  dependencies: [
                    .target(name: "Owner"),
                    .product(name: "Linter", package: "swift-linter"),
                  ]
                )
              ]
            )
            """
        let findings = Lint.Rule.`bare string dependency Tests`.findings(source: source)
        #expect(findings.isEmpty)
    }

    // #24 section A: file-scope bindings are resolvable in a manifest,
    // since a manifest is a single file by construction.

    @Test
    func `constant-declared target name in dependencies array is flagged at the reference`() {
        let source = """
            let owner = "Owner"
            let package = Package(
              targets: [
                .target(name: "Consumer", dependencies: [owner])
              ]
            )
            """
        let findings = Lint.Rule.`bare string dependency Tests`.findings(source: source)
        #expect(findings.count == 1)
    }

    @Test
    func `hoisted dependency array constant is flagged`() {
        let source = """
            let sharedDeps: [Target.Dependency] = ["A"]
            let package = Package(
              targets: [
                .target(name: "Consumer", dependencies: sharedDeps)
              ]
            )
            """
        let findings = Lint.Rule.`bare string dependency Tests`.findings(source: source)
        #expect(findings.count == 1)
    }

    @Test
    func `concatenated dependency arrays are both flagged`() {
        let source = """
            let base: [Target.Dependency] = ["A"]
            let extra: [Target.Dependency] = ["B"]
            let package = Package(
              targets: [
                .target(name: "Consumer", dependencies: base + extra)
              ]
            )
            """
        let findings = Lint.Rule.`bare string dependency Tests`.findings(source: source)
        #expect(findings.count == 2)
    }

    @Test
    func `computed dependency value is unmeasured`() {
        let source = """
            let package = Package(
              targets: [
                .target(name: "Consumer", dependencies: makeDeps())
              ]
            )
            """
        let observation = Lint.Rule.`bare string dependency Tests`.observation(source: source)
        #expect(observation.findings.isEmpty)
        guard case .unmeasured = observation.coverage else {
            Issue.record("computed dependency array was accepted as measured")
            return
        }
    }

    @Test
    func `each bare string fires once across target kinds`() {
        let source = """
            let package = Package(
              targets: [
                .target(name: "A", dependencies: ["B", .target(name: "C"), "D"]),
                .testTarget(name: "A Tests", dependencies: ["A"]),
                .executableTarget(name: "tool", dependencies: ["A"]),
                .macro(name: "Macro", dependencies: ["A"]),
                .plugin(name: "Plugin", capability: .buildTool(), dependencies: ["tool"]),
              ]
            )
            """
        let findings = Lint.Rule.`bare string dependency Tests`.findings(source: source)
        #expect(findings.count == 6)
    }
}

extension Lint.Rule.`bare string dependency Tests`.`Edge Case` {
    @Test
    func `string literal inside a path argument does not fire`() {
        let source = """
            let package = Package(
              targets: [
                .target(
                  name: "Consumer",
                  path: "Sources/Consumer",
                  dependencies: [.target(name: "Owner")]
                )
              ]
            )
            """
        let findings = Lint.Rule.`bare string dependency Tests`.findings(source: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `dot byName dependency is flagged - same resolution ambiguity as a bare string`() {
        // Regression fix: `.byName(name:)` is the EXACT harm the rule's
        // own message names ("SwiftPM resolves a bare string as
        // `.byName`, which binds to whatever it resolves first") — this
        // previously passed clean, contradicting the message.
        let source = """
            let package = Package(
              targets: [
                .target(
                  name: "Consumer",
                  path: "Sources/Consumer",
                  dependencies: [.byName(name: "Owner")]
                )
              ]
            )
            """
        let findings = Lint.Rule.`bare string dependency Tests`.findings(source: source)
        #expect(findings.count == 1)
    }

    @Test
    func `dependencies label on a non-target call does not fire`() {
        let source = """
            let helper = configure(dependencies: ["Owner"])
            let package = Package(
              dependencies: [
                .package(url: "https://example.com/owner.git", branch: "main")
              ]
            )
            """
        let findings = Lint.Rule.`bare string dependency Tests`.findings(source: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `versioned manifest variants are in surface`() {
        let source = """
            let package = Package(
              targets: [.target(name: "A", dependencies: ["B"])]
            )
            """
        let findings = Lint.Rule.`bare string dependency Tests`.findings(
            source: source,
            file: "Package@swift-6.0.swift"
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`bare string dependency Tests`.Integration {
    @Test
    func `non-manifest files are out of scope entirely`() {
        let source = """
            let list = build(dependencies: ["Owner"])
            let target = Target.target(name: "A", dependencies: ["B"])
            """
        let findings = Lint.Rule.`bare string dependency Tests`.findings(
            source: source,
            file: "Sources/Consumer/Graph.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `nested test manifest is in surface`() {
        let source = """
            let package = Package(
              name: "testing",
              dependencies: [.package(path: "..")],
              targets: [.testTarget(name: "Snapshot Tests", dependencies: ["Module"])]
            )
            """
        let findings = Lint.Rule.`bare string dependency Tests`.findings(
            source: source,
            file: "Tests/Package.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `self-firing control catches the external idiom verbatim`() {
        // The bare-string form as it arrives with copied external code.
        let source = """
            let package = Package(
              name: "copied",
              targets: [
                .target(name: "Copied", dependencies: ["ArgumentParser"])
              ]
            )
            """
        let findings = Lint.Rule.`bare string dependency Tests`.findings(source: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`bare string dependency Tests`.`Edge Case` {
    @Test
    func `a manifest that does not parse is unmeasured, not clean`() {
        let observation = Lint.Rule.`bare string dependency Tests`.observation(
            source: """
                let package = Package(name: "A", targets: [.target(name: "A")])
                let package = Package(
                """
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.coverage == .unmeasured(.unsupportedSourceShape("the manifest does not parse")))
    }

    @Test
    func `two Package initializers are unmeasured`() {
        let observation = Lint.Rule.`bare string dependency Tests`.observation(
            source: """
                let package = Package(name: "A", targets: [.target(name: "A", dependencies: ["B"])])
                let other = Package(name: "B")
                """
        )
        #expect(observation.findings.isEmpty)
        #expect(
            observation.coverage
                == .unmeasured(.unsupportedSourceShape("expected at most one Package initializer; found 2"))
        )
    }

    @Test
    func `a valid manifest with one Package initializer is still measured`() {
        let violating = Lint.Rule.`bare string dependency Tests`.observation(
            source: """
                let package = Package(name: "A", targets: [.target(name: "A", dependencies: ["B"])])
                """
        )
        #expect(violating.coverage == .measured)
        #expect(violating.findings.count == 1)
        let clean = Lint.Rule.`bare string dependency Tests`.observation(
            source: """
                let package = Package(name: "A", targets: [.target(name: "A", dependencies: [.target(name: "B")])])
                """
        )
        #expect(clean.coverage == .measured)
        #expect(clean.findings.isEmpty)
    }
}
