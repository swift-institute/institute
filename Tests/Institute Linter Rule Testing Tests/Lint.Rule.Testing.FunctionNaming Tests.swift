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

@testable import Institute_Linter_Rule_Testing

extension Lint.Rule {
    @Suite
    struct `test function naming Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`test function naming Tests` {
    static func findings(
        in source: String,
        file: String = "Sources/X/Test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`test function naming`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`test function naming Tests`.Unit {
    @Test
    func `Test func with backticked descriptive name is permitted`() {
        let source = """
            @Test
            func `init creates empty buffer`() {}
            """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Test func with camelCase name is flagged`() {
        let source = """
            @Test
            func testInitCreatesEmptyBuffer() {}
            """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-Test func with camelCase name is not flagged`() {
        let source = """
            func helperFunction() {}
            """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `qualified @Testing_Test func with camelCase name is flagged`() {
        let source = """
            @Testing.Test
            func testInitCreatesEmptyBuffer() {}
            """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Test func with multi-word backticked name is permitted`() {
        let source = """
            @Test
            func `Memory.Address from UnsafeRawPointer preserves identity`() {}
            """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Test with arguments and camelCase name is flagged`() {
        let source = """
            @Test(.tags(.fast))
            func runStuff() {}
            """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `single-word backticked Test func is permitted`() {
        // Backtick-escape exemption (added 2026-05-15): single-word
        // backticked names like `\`comparison\`` satisfy the rule's intent
        // (descriptive, not CamelCase) even without a space. The author
        // opted into the backtick form, which signals declarative naming
        // even for single-concept tests.
        let source = """
            @Test
            func `comparison`() {}
            """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `single-word backticked Test func with @Test args is permitted`() {
        let source = """
            @Test(.tags(.fast))
            func `equality`() {}
            """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `plain single-word lowercase Test func is permitted (no backticks needed)`() {
        // The rule's actual anti-pattern is CamelCase (legacy XCTest), not
        // "lacks backticks". A plain single-word identifier like `comparison`
        // is a valid Swift name — backticks add no value because the identifier
        // has no whitespace/special-char/keyword conflict. Refined 2026-05-15:
        // rule fires ONLY on CamelCase (internal uppercase letters); plain
        // non-CamelCase single-word identifiers pass.
        let source = """
            @Test
            func comparison() {}
            """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `plain Test func with all-lowercase compound (no internal uppercase) is permitted`() {
        // `equality` — single-word lowercase, no internal uppercase, no
        // backticks. Identifier is clean Swift; backticks would add no value.
        let source = """
            @Test
            func equality() {}
            """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
