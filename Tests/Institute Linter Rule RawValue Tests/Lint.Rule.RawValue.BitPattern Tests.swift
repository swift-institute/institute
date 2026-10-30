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

@testable import Institute_Linter_Rule_RawValue

extension Lint.Rule {
    @Suite
    struct `bitpattern rawvalue chain Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct `Evasion` {}
        @Suite struct `Negative` {}
    }
}

extension Lint.Rule.`bitpattern rawvalue chain Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`bitpattern rawvalue chain`.observe(parsed, .warning).findings
    }

    /// Findings against a run whose brand pre-pass stamped `types`
    /// (#23 finding 21: `Lint.Brand.owned` whole-run self-suppression).
    static func findings(
        in source: Swift::String,
        types: Swift::Set<Swift::String>
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, types: types)
        return Lint.Rule.`bitpattern rawvalue chain`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`bitpattern rawvalue chain Tests`.Unit {
    @Test
    func `Int(bitPattern: x.rawValue) is flagged`() {
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(
            in: "let i = Int(bitPattern: x.rawValue)"
        )
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "bitpattern rawvalue chain")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `UInt(bitPattern: x.rawValue) is flagged`() {
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(
            in: "let i = UInt(bitPattern: x.rawValue)"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `message names the real engine-recognized suppression directive`() {
        // Regression guard: the message must cite the `swift-linter:` namespace
        // and the real space-separated rule id — not the SwiftLint-era
        // the SwiftLint `swiftlint` namespace with an underscored id, which the engine's
        // malformed-suppression rule does not recognize as a directive at all.
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(
            in: "let i = Int(bitPattern: x.rawValue)"
        )
        #expect(findings.count == 1)
        if let message = findings.first?.message {
            #expect(message.contains("swift-linter:disable:next bitpattern rawvalue chain"))
            #expect(!message.contains("swiftlint:disable:next bitpattern_rawvalue_chain"))
        }
    }
}

extension Lint.Rule.`bitpattern rawvalue chain Tests`.Evasion {
    @Test
    func `Int.init(bitPattern: x.rawValue) (typename-swap via .init) is flagged`() {
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(
            in: "let i = Int.init(bitPattern: x.rawValue)"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `self.init(bitPattern: x.rawValue) (typename-swap via self) is flagged`() {
        let source = """
            struct W {
                init(value: X) {
                    self.init(bitPattern: value.rawValue)
                }
                init(bitPattern: Int) {}
            }
            """
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Int8(bitPattern: x.rawValue) (sized integer typename-swap) is flagged`() {
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(
            in: "let i = Int8(bitPattern: x.rawValue)"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Nested rawValue Int(bitPattern: foo.bar.rawValue) is flagged`() {
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(
            in: "let i = Int(bitPattern: foo.bar.rawValue)"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Subscript Int(bitPattern: arr[i].rawValue) is flagged`() {
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(
            in: "let i = Int(bitPattern: arr[i].rawValue)"
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`bitpattern rawvalue chain Tests`.Negative {
    @Test
    func `Int(bitPattern: typedValue) (no rawValue chain) is NOT flagged`() {
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(
            in: "let i = Int(bitPattern: cardinal)"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Int(bitPattern: foo.bar) (non-rawValue member) is NOT flagged`() {
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(
            in: "let i = Int(bitPattern: foo.bar)"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Int(other: x.rawValue) (different label) is NOT flagged`() {
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(
            in: "let i = Int(other: x.rawValue)"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Int(x.rawValue) (no bitPattern label) is NOT flagged`() {
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(
            in: "let i = Int(x.rawValue)"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Comment containing the pattern is NOT flagged`() {
        let source = """
            // Int(bitPattern: x.rawValue) is the canonical anti-pattern
            let y = 42
            """
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `String literal containing the pattern is NOT flagged`() {
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(
            in: #"let s = "Int(bitPattern: x.rawValue)""#
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Empty file produces no findings`() {
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`bitpattern rawvalue chain Tests`.`Edge Case` {
    @Test
    func `Multi-line Int(bitPattern: ... rawValue) is flagged`() {
        let source = """
            let i = Int(
                bitPattern: x.rawValue
            )
            """
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Multiple bitPattern calls each flagged`() {
        let source = """
            let a = Int(bitPattern: x.rawValue)
            let b = UInt(bitPattern: y.rawValue)
            """
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `Custom severity is honored`() {
        let source = "let i = Int(bitPattern: x.rawValue)"
        let parsed = Lint.Source.parsed(from: source)
        let findings = Lint.Rule.`bitpattern rawvalue chain`.observe(parsed, .error).findings
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].severity == .error)
        }
    }

    @Test
    func `Cardinal brand-owner run self-suppresses`() {
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(
            in: "let i = Int(bitPattern: x.rawValue)",
            types: ["Cardinal"]
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a non-brand-owner consumer run still fires`() {
        let findings = Lint.Rule.`bitpattern rawvalue chain Tests`.findings(
            in: "let i = Int(bitPattern: x.rawValue)",
            types: ["SomeConsumerType"]
        )
        #expect(findings.count == 1)
    }
}
