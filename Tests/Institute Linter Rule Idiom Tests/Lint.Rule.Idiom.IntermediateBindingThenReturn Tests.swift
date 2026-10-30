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

@testable import Institute_Linter_Rule_Idiom

extension Lint.Rule {
    @Suite
    struct `intermediate binding then return Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`intermediate binding then return Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`intermediate binding then return`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`intermediate binding then return Tests`.Unit {
    @Test
    func `let then return same identifier is flagged`() {
        let source = """
            func op() -> Int {
                let result = compute()
                return result
            }
            """
        let findings = Lint.Rule.`intermediate binding then return Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "intermediate binding then return")
        }
    }
}

extension Lint.Rule.`intermediate binding then return Tests`.`Edge Case` {
    @Test
    func `var binding is NOT flagged`() {
        let source = """
            func op() -> Int {
                var result = compute()
                result.mutate()
                return result
            }
            """
        let findings = Lint.Rule.`intermediate binding then return Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `explicit type annotation is NOT flagged`() {
        let source = """
            func op() -> Foo {
                let result: Foo = compute()
                return result
            }
            """
        let findings = Lint.Rule.`intermediate binding then return Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `multi-use binding is NOT flagged`() {
        let source = """
            func op() -> Int {
                let result = compute()
                use(result)
                return result
            }
            """
        let findings = Lint.Rule.`intermediate binding then return Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `return of different expression is NOT flagged`() {
        let source = """
            func op() -> Int {
                let local = compute()
                return other(local)
            }
            """
        let findings = Lint.Rule.`intermediate binding then return Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
