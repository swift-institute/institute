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

@testable import Institute_Linter_Rule_Structure

extension Lint.Rule {
    @Suite
    struct `type transform placement Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`type transform placement Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`type transform placement`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`type transform placement Tests`.Unit {
    @Test
    func `toFoo returning Foo is flagged`() {
        let source = """
            extension Source {
                public func toFoo() -> Foo { fatalError() }
            }
            """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "type transform placement")
        }
    }

    @Test
    func `asBar returning Bar is flagged`() {
        let source = """
            extension Source {
                public func asBar() -> Bar { fatalError() }
            }
            """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`type transform placement Tests`.`Edge Case` {
    @Test
    func `static method is NOT flagged`() {
        let source = """
            extension Foo {
                public static func from(_ source: Source) -> Foo { fatalError() }
            }
            """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `toString convention method is NOT flagged when return is different`() {
        let source = """
            extension Foo {
                public func toRepresentation() -> Bar { fatalError() }
            }
            """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `method without to or as prefix is NOT flagged`() {
        let source = """
            extension Foo {
                public func describe() -> Bar { fatalError() }
            }
            """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // MARK: - #28 defect 6: protocol requirements have no body to relocate

    @Test
    func `toFoo requirement in a protocol is NOT flagged`() {
        let source = """
            protocol P {
                func toFoo() -> Foo
            }
            """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `the same shape in a struct is still flagged (control)`() {
        let source = """
            struct S {
                func toFoo() -> Foo { fatalError() }
            }
            """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // MARK: - #28 nit 5: IUO and any/some return-type leaf resolution

    @Test
    func `toFoo returning implicitly unwrapped optional Foo is flagged`() {
        let source = """
            extension Bar {
                public func toFoo() -> Foo! { fatalError() }
            }
            """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `toFoo returning any Foo is flagged`() {
        let source = """
            extension Bar {
                public func toFoo() -> any Foo { fatalError() }
            }
            """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // MARK: - test gap 2: the static-modifier branch was unreachable from its fixture

    @Test
    func `static func toFoo returning Foo is NOT flagged`() {
        let source = """
            extension Bar {
                public static func toFoo() -> Foo { fatalError() }
            }
            """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `class func toFoo returning Foo is NOT flagged`() {
        let source = """
            class Bar {
                public class func toFoo() -> Foo { fatalError() }
            }
            """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // #28 test gap 4 (remaining half): no #if-shaped fixture existed
    // anywhere in the pack. This rule visits FunctionDeclSyntax via
    // normal recursive descent, so a #if-guarded instance method is
    // reachable without any additional code — this fixture is the
    // regression pin for that fact.
    @Test
    func `toFoo guarded by if os is still flagged`() {
        let source = """
            struct Bar {
                #if os(Linux)
                func toFoo() -> Foo { fatalError() }
                #endif
            }
            """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
