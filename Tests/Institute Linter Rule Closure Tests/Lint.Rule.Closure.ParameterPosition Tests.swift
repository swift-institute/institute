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
    struct `parameter position Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`parameter position Tests` {
    static func findings(
        in source: String,
        file: String = "Sources/X/Test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`parameter position`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`parameter position Tests`.Unit {
    @Test
    func `closure-then-non-closure is flagged`() {
        let source = """
            func f(body: () -> Void, count: Int) {}
            """
        let findings = Lint.Rule.`parameter position Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-closure-then-closure is permitted`() {
        let source = """
            func f(count: Int, body: () -> Void) {}
            """
        let findings = Lint.Rule.`parameter position Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `multiple closures at the end is permitted`() {
        let source = """
            func f(count: Int, body: () -> Void, completion: () -> Void) {}
            """
        let findings = Lint.Rule.`parameter position Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `escaping closure trails (with attribute) is permitted`() {
        let source = """
            func f(count: Int, body: @escaping () -> Void) {}
            """
        let findings = Lint.Rule.`parameter position Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `escaping closure followed by non-closure is flagged`() {
        let source = """
            func f(body: @escaping () -> Void, label: String) {}
            """
        let findings = Lint.Rule.`parameter position Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `optional closure followed by non-closure is flagged`() {
        let source = """
            func f(handler: (() -> Void)?, label: String) {}
            """
        let findings = Lint.Rule.`parameter position Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `init also enforces`() {
        let source = """
            struct S {
                init(body: () -> Void, label: String) {}
            }
            """
        let findings = Lint.Rule.`parameter position Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`parameter position Tests`.`Edge Case` {
    @Test
    func `typed-throws thunk counts as closure`() {
        let source = """
            func f(body: () throws(MyError) -> Int, label: String) {}
            """
        let findings = Lint.Rule.`parameter position Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `function with no params is not flagged`() {
        let source = "func f() {}"
        let findings = Lint.Rule.`parameter position Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
