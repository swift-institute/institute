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

@testable import Institute_Linter_Rule_Closure

extension Lint.Rule {
    @Suite
    struct `lifecycle order Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`lifecycle order Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`lifecycle order`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`lifecycle order Tests`.Unit {
    @Test
    func `completion before unlabelled body is flagged`() {
        let source = """
            func perform(completion: @escaping (Result) -> Void, _ body: @escaping () -> Void) {}
            """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "lifecycle order")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `onError before unlabelled body is flagged`() {
        let source = """
            func op(onError: () -> Void, _ body: () -> Void) {}
            """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `cleanup before labelled body is flagged`() {
        let source = """
            func op(cleanup: () -> Void, body: () -> Void) {}
            """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `two completion-tier closures before body each flagged`() {
        let source = """
            func op(onError: () -> Void, cleanup: () -> Void, _ body: () -> Void) {}
            """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `body before setup is flagged`() {
        // setup MUST precede body; a body-tier closure appearing before a
        // later setup-tier closure is the setup-half of the documented
        // order being violated.
        let source = """
            func op(_ body: () -> Void, setup: () -> Void) {}
            """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `completion before setup is flagged`() {
        let source = """
            func op(completion: () -> Void, setup: () -> Void) {}
            """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `anonymous label with completion-tier internal name is flagged when before body`() {
        // Regression for the wildcard-always-body bug: `_ completion:` was
        // misclassified as .body purely from the wildcard external label,
        // ignoring the completion-tier internal name entirely.
        let source = """
            func run(_ completion: () -> Void, body: () -> Void) {}
            """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func
        `non-canonical external label with canonical internal name is classified by internal name`()
    {
        // A two-part parameter name where the external label doesn't match
        // any tier but the internal name does (`to completion:`) still
        // reads as completion-tier.
        let source = """
            func run(to completion: () -> Void, _ body: () -> Void) {}
            """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`lifecycle order Tests`.`Edge Case` {
    @Test
    func `body before completion is NOT flagged`() {
        let source = """
            func perform(_ body: () -> Void, completion: (Result) -> Void) {}
            """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `setup before body before completion is NOT flagged`() {
        let source = """
            func op(setup: () -> Void, _ body: () -> Void, completion: (Result) -> Void) {}
            """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `both labelled non-body and non-completion is NOT flagged`() {
        // progress / metric are domain labels, neither body nor completion;
        // rule can't disambiguate intent without an anchor.
        let source = """
            func op(progress: () -> Void, metric: () -> Void) {}
            """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `single closure is NOT flagged`() {
        let source = """
            func op(_ body: () -> Void) {}
            """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `completion without any body is NOT flagged`() {
        let source = """
            func op(completion: () -> Void, cleanup: () -> Void) {}
            """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        // No body-tier anchor — completion-tier closures alone are
        // out of scope here (could be intentional, e.g., a tear-down API).
        #expect(findings.isEmpty)
    }

    @Test
    func `non-closure parameters between closures do not confuse ordering`() {
        let source = """
            func op(completion: () -> Void, count: Int, _ body: () -> Void) {}
            """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
