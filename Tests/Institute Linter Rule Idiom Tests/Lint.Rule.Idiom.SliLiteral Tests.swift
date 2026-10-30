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
    struct `sli literal Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`sli literal Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`sli literal`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`sli literal Tests`.Unit {
    @Test
    func `Index literal in subscript is flagged`() {
        let source = """
            func read(_ slab: Slab) -> Element {
                slab[Index<Int>(Ordinal(UInt(0)))]
            }
            """
        let findings = Lint.Rule.`sli literal Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "sli literal")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `Tagged literal construction is flagged`() {
        let source = """
            let index = Tagged<Foo, Ordinal>(Ordinal(UInt(3)))
            """
        let findings = Lint.Rule.`sli literal Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `plain let Index literal binding is flagged`() {
        let source = """
            let i = Index<Element>(Ordinal(UInt(5)))
            """
        let findings = Lint.Rule.`sli literal Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `bare Index literal without generic arguments is flagged`() {
        let source = """
            let i = Index(Ordinal(UInt(7)))
            """
        let findings = Lint.Rule.`sli literal Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`sli literal Tests`.`Edge Case` {
    @Test
    func `Index over identifier runtime binding is NOT flagged`() {
        let source = """
            func read(_ slot: UInt) -> Element {
                storage[Index<Element>(Ordinal(UInt(slot)))]
            }
            """
        let findings = Lint.Rule.`sli literal Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `labeled unchecked construction is NOT flagged`() {
        // `Index(_unchecked: …)` is a different API surface ([CONV-015]).
        let source = """
            let i = Index(_unchecked: Ordinal(UInt(5)))
            """
        let findings = Lint.Rule.`sli literal Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `bare Ordinal UInt without Index wrapper is NOT flagged`() {
        let source = """
            let o = Ordinal(UInt(5))
            """
        let findings = Lint.Rule.`sli literal Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Index without the Ordinal UInt wrapper chain is NOT flagged`() {
        let source = """
            let i = Index<E>(o)
            """
        let findings = Lint.Rule.`sli literal Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `bare UInt literal alone is NOT flagged`() {
        let source = """
            let n = UInt(0)
            """
        let findings = Lint.Rule.`sli literal Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Index over member-access runtime binding is NOT flagged`() {
        let source = """
            func read(_ count: Count) -> Element {
                storage[Index<E>(Ordinal(UInt(count.rawValue)))]
            }
            """
        let findings = Lint.Rule.`sli literal Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
