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
    struct `variable named impl Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`variable named impl Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`variable named impl`.observe(parsed, .warning).findings
    }
}

// swiftlint:disable no_impl_obj_inst_bindings
// REASON: this suite's fixture sources deliberately embed impl/obj/inst-named bindings as
// string literals under test
// (self-referential fixture shape, rule-exemptions skill); re-enabled at end of file.
extension Lint.Rule.`variable named impl Tests`.Unit {
    @Test
    func `let impl is flagged`() {
        let source = "let impl = make()"
        let findings = Lint.Rule.`variable named impl Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "variable named impl")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `var impl is flagged`() {
        let source = "var impl = make()"
        let findings = Lint.Rule.`variable named impl Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `let _impl is flagged`() {
        let source = "let _impl = make()"
        let findings = Lint.Rule.`variable named impl Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `let impl with type annotation is flagged`() {
        let source = "let impl: Actor = Actor()"
        let findings = Lint.Rule.`variable named impl Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `let impl inside function body is flagged`() {
        let source = """
            func setup() {
                let impl = factory()
                _ = impl
            }
            """
        let findings = Lint.Rule.`variable named impl Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple impl bindings are all flagged`() {
        let source = """
            let impl = a()
            var _impl = b()
            let impl2: Int = 0
            _ = impl2
            """
        // `impl2` is NOT flagged (substring match disallowed). 2 hits expected.
        let findings = Lint.Rule.`variable named impl Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`variable named impl Tests`.`Edge Case` {
    @Test
    func `let implementation is NOT flagged`() {
        let source = "let implementation = make()"
        let findings = Lint.Rule.`variable named impl Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `let implOf is NOT flagged`() {
        let source = "let implOf = make()"
        let findings = Lint.Rule.`variable named impl Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `func parameter named impl is NOT flagged`() {
        // The rule targets variable bindings, not function parameters.
        let source = "func f(impl: Int) -> Int { impl }"
        let findings = Lint.Rule.`variable named impl Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `impl in a string literal is NOT flagged`() {
        let source = "let s = \"let impl = make()\""
        let findings = Lint.Rule.`variable named impl Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `empty file produces no findings`() {
        let findings = Lint.Rule.`variable named impl Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }
}
// swiftlint:enable no_impl_obj_inst_bindings
