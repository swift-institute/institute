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

@testable import Institute_Linter_Rule_Cardinal

extension Lint.Rule {
    @Suite
    struct `zero or one literal Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct `Negative` {}
    }
}

extension Lint.Rule.`zero or one literal Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`zero or one literal`.observe(parsed, .warning).findings
    }

    /// Findings against a run whose brand pre-pass stamped `types`.
    static func findings(
        in source: Swift::String,
        types: Swift::Set<Swift::String>
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, types: types)
        return Lint.Rule.`zero or one literal`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`zero or one literal Tests`.`Edge Case` {
    @Test
    func `Cardinal brand-owner run self-suppresses (§A)`() {
        // The run declares `Cardinal` — its own `Cardinal(0)` boundary
        // constructions are legitimate. Zero findings.
        let findings = Lint.Rule.`zero or one literal Tests`.findings(
            in: "let c = Cardinal(0)",
            types: ["Cardinal"]
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a different brand-owner still fires on a stray Cardinal(0) (§A)`() {
        // This rule is brand-SPECIFIC to `Cardinal`: a run that declares
        // `Ordinal` (not `Cardinal`) still catches a stray `Cardinal(0)`.
        let findings = Lint.Rule.`zero or one literal Tests`.findings(
            in: "let c = Cardinal(0)",
            types: ["Ordinal"]
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`zero or one literal Tests`.Unit {
    @Test
    func `Cardinal(0) is flagged`() {
        let findings = Lint.Rule.`zero or one literal Tests`.findings(in: "let c = Cardinal(0)")
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "zero or one literal")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `Cardinal(1) is flagged`() {
        let findings = Lint.Rule.`zero or one literal Tests`.findings(in: "let c = Cardinal(1)")
        #expect(findings.count == 1)
    }

    @Test
    func `Cardinal.init(0) is flagged`() {
        let findings = Lint.Rule.`zero or one literal Tests`.findings(
            in: "let c = Cardinal.init(0)"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Cardinal-of-T angle-bracket generic-specialized (0) is flagged`() {
        // The doc advertises `Cardinal<T>(0)` explicitly; this exercises
        // the `GenericSpecializationExprSyntax` branch of `calleeTypeName`.
        let findings = Lint.Rule.`zero or one literal Tests`.findings(
            in: "let c = Cardinal<Int>(0)"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Cardinal-of-T angle-bracket generic-specialized dot init(1) is flagged`() {
        let findings = Lint.Rule.`zero or one literal Tests`.findings(
            in: "let c = Cardinal<Int>.init(1)"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Cardinal-qualified Cardinal(0) is flagged`() {
        // Mirror image of the `.init` recursion: a qualified reference to
        // the type itself, with no `.init` in between.
        let findings = Lint.Rule.`zero or one literal Tests`.findings(
            in: "let c = Cardinal.Cardinal(0)"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Cardinal-qualified Cardinal dot init(1) is flagged`() {
        let findings = Lint.Rule.`zero or one literal Tests`.findings(
            in: "let c = Cardinal.Cardinal.init(1)"
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`zero or one literal Tests`.Negative {
    @Test
    func `Cardinal(2) is NOT flagged`() {
        let findings = Lint.Rule.`zero or one literal Tests`.findings(in: "let c = Cardinal(2)")
        #expect(findings.isEmpty)
    }

    @Test
    func `Cardinal(unchecked, 0) (labeled single-arg) is NOT flagged`() {
        let findings = Lint.Rule.`zero or one literal Tests`.findings(
            in: "let c = Cardinal(unchecked: 0)"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Cardinal(0, radix, 10) (true multi-arg) is NOT flagged`() {
        // Regression guard: an actual multi-argument call site. The
        // previous fixture under this title was a single labeled argument
        // and never reached the `node.arguments.count == 1` guard at all —
        // this exercises that guard directly.
        let findings = Lint.Rule.`zero or one literal Tests`.findings(
            in: "let c = Cardinal(0, radix: 10)"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Cardinal(rawValue: 0) (labeled arg) is NOT flagged`() {
        let findings = Lint.Rule.`zero or one literal Tests`.findings(
            in: "let c = Cardinal(rawValue: 0)"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Other type with literal 0 is NOT flagged`() {
        let findings = Lint.Rule.`zero or one literal Tests`.findings(in: "let i = Int(0)")
        #expect(findings.isEmpty)
    }

    @Test
    func `Cardinal.zero (canonical accessor) is NOT flagged`() {
        let findings = Lint.Rule.`zero or one literal Tests`.findings(in: "let c = Cardinal.zero")
        #expect(findings.isEmpty)
    }

    @Test
    func `Cardinal in string literal is NOT flagged`() {
        let findings = Lint.Rule.`zero or one literal Tests`.findings(in: #"let s = "Cardinal(0)""#)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`zero or one literal Tests`.`Edge Case` {
    @Test
    func `Multi-line Cardinal with newline-arg is flagged`() {
        let source = """
            let c = Cardinal(
                0
            )
            """
        let findings = Lint.Rule.`zero or one literal Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Custom severity is honored`() {
        let source = "let c = Cardinal(0)"
        let parsed = Lint.Source.parsed(from: source)
        let findings = Lint.Rule.`zero or one literal`.observe(parsed, .error).findings
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].severity == .error)
        }
    }

    @Test
    func `Empty file produces no findings`() {
        let findings = Lint.Rule.`zero or one literal Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }
}
