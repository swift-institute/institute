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

@testable import Institute_Linter_Rule_Memory

extension Lint.Rule {
    @Suite
    struct `borrowing self short circuit Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`borrowing self short circuit Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`borrowing self short circuit`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`borrowing self short circuit Tests`.Unit {
    @Test
    func `less-than operator with borrowing Self and OR is flagged`() {
        let source = """
            public static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
                lhs.priority < rhs.priority || (lhs.priority == rhs.priority && lhs.sequence < rhs.sequence)
            }
            """
        let findings = Lint.Rule.`borrowing self short circuit Tests`.findings(in: source)
        // Two operators in the body: `||` and `&&` — both flagged.
        #expect(findings.count == 2)
        if findings.count >= 1 {
            #expect(findings[0].identifier == "borrowing self short circuit")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `equality operator with borrowing Self and AND is flagged`() {
        let source = """
            public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
                lhs.x == rhs.x && lhs.y == rhs.y
            }
            """
        let findings = Lint.Rule.`borrowing self short circuit Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `short-circuit inside a nested closure is NOT flagged - closures are their own scope`() {
        // #25 defect 9 remainder: the finder's ClosureExprSyntax visit
        // returns .skipChildren — a short-circuit that lives inside a
        // closure body is a different capture/scope shape, previously
        // untested.
        let source = """
            public static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
                let compare = { lhs.priority < rhs.priority || lhs.sequence < rhs.sequence }
                return compare()
            }
            """
        let findings = Lint.Rule.`borrowing self short circuit Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`borrowing self short circuit Tests`.`Edge Case` {
    @Test
    func `tuple comparison alternative is NOT flagged`() {
        let source = """
            public static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
                (lhs.a, lhs.b) < (rhs.a, rhs.b)
            }
            """
        let findings = Lint.Rule.`borrowing self short circuit Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `local let bindings alternative is NOT flagged`() {
        let source = """
            public static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
                let la = lhs.a
                let lb = lhs.b
                let ra = rhs.a
                let rb = rhs.b
                if la < ra { return true }
                if la > ra { return false }
                return lb < rb
            }
            """
        let findings = Lint.Rule.`borrowing self short circuit Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-operator function with borrowing Self is NOT flagged`() {
        let source = """
            public func compare(_ rhs: borrowing Self) -> Bool {
                self.a < rhs.a || self.b < rhs.b
            }
            """
        let findings = Lint.Rule.`borrowing self short circuit Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `operator on non-borrowing parameters is NOT flagged`() {
        let source = """
            public static func + (lhs: Int, rhs: Int) -> Int {
                lhs > 0 && rhs > 0 ? lhs + rhs : 0
            }
            """
        let findings = Lint.Rule.`borrowing self short circuit Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `operator with borrowing Self but no short-circuit body is NOT flagged`() {
        let source = """
            public static func + (lhs: borrowing Self, rhs: borrowing Self) -> Self {
                Self(rawValue: lhs.rawValue + rhs.rawValue)
            }
            """
        let findings = Lint.Rule.`borrowing self short circuit Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
