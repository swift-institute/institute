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
    struct `chained rawvalue access Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct `Evasion` {}
        @Suite struct `Negative` {}
    }
}

extension Lint.Rule.`chained rawvalue access Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`chained rawvalue access`.observe(parsed, .warning).findings
    }

    /// Findings against a run whose brand pre-pass stamped `types`
    /// (#23 finding 21: `Lint.Brand.owned` whole-run self-suppression).
    static func findings(
        in source: Swift::String,
        types: Swift::Set<Swift::String>
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, types: types)
        return Lint.Rule.`chained rawvalue access`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`chained rawvalue access Tests`.Unit {
    @Test
    func `x.rawValue.foo is flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(
            in: "let n = x.rawValue.foo"
        )
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "chained rawvalue access")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `x.rawValue.foo() is flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(
            in: "let n = x.rawValue.foo()"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `message names the real engine-recognized suppression directive`() {
        // Regression guard: the message must cite the `swift-linter:` namespace
        // and the real space-separated rule id — not the SwiftLint-era
        // the SwiftLint `swiftlint` namespace with an underscored id, which the engine's
        // malformed-suppression rule does not recognize as a directive at all.
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(
            in: "let n = x.rawValue.foo"
        )
        #expect(findings.count == 1)
        if let message = findings.first?.message {
            #expect(message.contains("swift-linter:disable:next chained rawvalue access"))
            #expect(!message.contains("swiftlint:disable:next chained_rawvalue_access"))
        }
    }
}

extension Lint.Rule.`chained rawvalue access Tests`.Evasion {
    @Test
    func `Paren-wrapped (x.rawValue).foo is flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(
            in: "let n = (x.rawValue).foo"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Double-paren ((x.rawValue)).foo is flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(
            in: "let n = ((x.rawValue)).foo"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Optional-chained x-rawValue-question-mark-dot-foo is flagged`() {
        // `?` optional chaining is as semantically transparent to this
        // predicate as parenthesization — both wrap the same
        // `MemberAccessExprSyntax(base: x, name: rawValue)` shape.
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(
            in: "let n = x.rawValue?.foo"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Force-unwrapped x-rawValue-bang-dot-foo is flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(
            in: "let n = x.rawValue!.foo"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Paren-wrapped optional-chained (x-rawValue)-question-mark-dot-foo is flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(
            in: "let n = (x.rawValue)?.foo"
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`chained rawvalue access Tests`.Negative {
    @Test
    func `Bare x.rawValue (terminal access) is NOT flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: "let n = x.rawValue")
        #expect(findings.isEmpty)
    }

    @Test
    func `x.rawValue inside string literal is NOT flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(
            in: #"let s = "x.rawValue.foo""#
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `x.foo.rawValue (rawValue at end of chain) is NOT flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(
            in: "let n = x.foo.rawValue"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Empty file produces no findings`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`chained rawvalue access Tests`.`Edge Case` {
    @Test
    func `x.rawValue in comment is NOT flagged`() {
        let source = """
            // x.rawValue.foo is the canonical anti-pattern
            let y = 42
            """
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Nested chain a.b.rawValue.c is flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(
            in: "let n = a.b.rawValue.c"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Multiple chained accesses each flagged`() {
        let source = """
            let a = x.rawValue.foo
            let b = y.rawValue.bar
            """
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `Custom severity is honored`() {
        let source = "let n = x.rawValue.foo"
        let parsed = Lint.Source.parsed(from: source)
        let findings = Lint.Rule.`chained rawvalue access`.observe(parsed, .error).findings
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].severity == .error)
        }
    }

    @Test
    func `Cardinal brand-owner run self-suppresses`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(
            in: "let n = x.rawValue.foo",
            types: ["Cardinal"]
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a non-brand-owner consumer run still fires`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(
            in: "let n = x.rawValue.foo",
            types: ["SomeConsumerType"]
        )
        #expect(findings.count == 1)
    }
}
