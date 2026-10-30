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

@testable import Institute_Linter_Rule_Naming

extension Lint.Rule {
    @Suite
    struct `unification typealias Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`unification typealias Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`unification typealias`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`unification typealias Tests`.Unit {
    @Test
    func `rename-bridge typealias is flagged`() {
        let source = """
            public typealias SourceLocation = Text.Location
            """
        let findings = Lint.Rule.`unification typealias Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "unification typealias")
        }
    }
}

extension Lint.Rule.`unification typealias Tests`.`Edge Case` {
    @Test(arguments: [
        ("sRGB", "SRGB"),
        ("SRGB", "sRGB"),
        ("srgb", "SRGB"),
        ("sRGB", "Srgb"),
        ("event", "Event"),
        ("URL", "Url"),
        ("évent", "Évent"),
        ("`sRGB`", "SRGB"),
        ("sRGB", "`SRGB`"),
    ])
    func `case-only leaf spellings preserve the domain name`(alias: String, leaf: String) {
        let findings = Lint.Rule.`unification typealias Tests`.findings(
            in: "public typealias \(alias) = Domain.Nested.\(leaf)"
        )
        #expect(findings.isEmpty)
    }

    @Test(arguments: [
        ("sRGB", "SRGBA"),
        ("SR_GB", "SRGB"),
        ("_SRGB", "SRGB"),
        ("évent", "Event"),
        ("`sRGB`", "SRGBA"),
    ])
    func `different leaf names remain rename bridges`(alias: String, leaf: String) {
        let findings = Lint.Rule.`unification typealias Tests`.findings(
            in: "public typealias \(alias) = Domain.Nested.\(leaf)"
        )
        #expect(findings.count == 1)
        #expect(findings.allSatisfy { $0.identifier == "unification typealias" })
    }

    @Test
    func `same-leaf typealias is NOT flagged`() {
        // Handled by [API-NAME-004a] NamespaceAdoption instead.
        let source = """
            public typealias Event = Kernel.Event
            """
        let findings = Lint.Rule.`unification typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `generic instantiation typealias is NOT flagged`() {
        let source = """
            public typealias IntArray = Array<Int>
            """
        let findings = Lint.Rule.`unification typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-member-type RHS is NOT flagged`() {
        let source = """
            public typealias Counter = Int
            """
        let findings = Lint.Rule.`unification typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Swift stdlib bridge is NOT flagged`() {
        // SE-0499 (Swift 6.4+) lets institute protocol forks alias to the
        // stdlib protocol without losing ~Copyable support. The typealias
        // is a namespace alias TO the stdlib, not a rename bridge between
        // co-equal type definitions.
        let source = """
            extension Equation {
                public typealias `Protocol` = Swift.Equatable
            }
            """
        let findings = Lint.Rule.`unification typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Swift Hashable stdlib bridge is NOT flagged`() {
        let source = """
            extension Hash {
                public typealias `Protocol` = Swift.Hashable
            }
            """
        let findings = Lint.Rule.`unification typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-Swift base namespace bridge IS flagged`() {
        // Only top-level `Swift.X` is exempted. A rename bridge to any
        // other base namespace remains the [API-NAME-004] anti-pattern.
        let source = """
            public typealias SourceLocation = Text.Location
            """
        let findings = Lint.Rule.`unification typealias Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `associatedtype satisfier in conforming extension is NOT flagged`() {
        // `extension Unicode.Scalar: Carrier.Protocol { typealias Underlying = Unicode.Scalar }`
        // satisfies `Carrier.Protocol.Underlying`. The LHS name is forced
        // by the protocol's associatedtype; this is not a discretionary
        // [API-NAME-004] rename bridge.
        let source = """
            extension Unicode.Scalar: Carrier.`Protocol` {
                public typealias Underlying = Unicode.Scalar
            }
            """
        let findings = Lint.Rule.`unification typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `rename bridge in plain extension IS still flagged`() {
        // Extension WITHOUT an inheritance clause is not introducing a
        // protocol conformance — the LHS != RHS-leaf rename is a
        // discretionary bridge, not an associatedtype satisfier.
        let source = """
            extension Tagged {
                public typealias SourceLocation = Text.Location
            }
            """
        let findings = Lint.Rule.`unification typealias Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
