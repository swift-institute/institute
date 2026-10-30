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
    struct `bounded index static capacity Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`bounded index static capacity Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`bounded index static capacity`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`bounded index static capacity Tests`.Unit {
    @Test
    func `Int subscript on value-generic struct is flagged`() {
        let source = """
            struct Buffer<let N: Int> {
                subscript(index: Int) -> Int { 0 }
            }
            """
        let findings = Lint.Rule.`bounded index static capacity Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "bounded index static capacity")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `Swift dot Int subscript on value-generic is flagged`() {
        let source = """
            struct Buffer<let N: Int> {
                subscript(i: Swift.Int) -> Element { fatalError() }
            }
            """
        let findings = Lint.Rule.`bounded index static capacity Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `value-generic with mixed Element + N parameter is flagged`() {
        let source = """
            struct FixedArray<Element, let Count: Int> {
                subscript(i: Int) -> Element { fatalError() }
            }
            """
        let findings = Lint.Rule.`bounded index static capacity Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Int subscript on value-generic actor is flagged`() {
        let source = """
            actor Pool<let N: Int> {
                subscript(i: Int) -> Job { fatalError() }
            }
            """
        let findings = Lint.Rule.`bounded index static capacity Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // #24 defect 11 test gap: the ClassDeclSyntax and EnumDeclSyntax
    // visitors carried the same bookkeeping as struct/actor but had no
    // fixture reaching them.

    @Test
    func `Int subscript on value-generic class is flagged`() {
        let source = """
            class Buffer<let N: Int> {
                subscript(i: Int) -> Element { fatalError() }
            }
            """
        let findings = Lint.Rule.`bounded index static capacity Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Int subscript on value-generic enum is flagged`() {
        let source = """
            enum Buffer<let N: Int> {
                case slot
                subscript(i: Int) -> Element { fatalError() }
            }
            """
        let findings = Lint.Rule.`bounded index static capacity Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`bounded index static capacity Tests`.`Edge Case` {
    @Test
    func `Bounded subscript on value-generic is NOT flagged`() {
        let source = """
            struct Buffer<let N: Int> {
                subscript(i: Index<Element>.Bounded<N>) -> Element { fatalError() }
            }
            """
        let findings = Lint.Rule.`bounded index static capacity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Int subscript on non-value-generic struct is NOT flagged`() {
        let source = """
            struct DynamicArray<Element> {
                subscript(i: Int) -> Element { fatalError() }
            }
            """
        let findings = Lint.Rule.`bounded index static capacity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Int subscript on non-generic struct is NOT flagged`() {
        let source = """
            struct Pile {
                subscript(i: Int) -> Int { 0 }
            }
            """
        let findings = Lint.Rule.`bounded index static capacity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Int subscript in extension out of per-file scope is NOT flagged`() {
        // Extension's bound visibility is opaque per-file (no `<let N>`
        // in the extension syntax). Rule conservatively skips.
        let source = """
            extension Buffer {
                subscript(i: Int) -> Element { fatalError() }
            }
            """
        let findings = Lint.Rule.`bounded index static capacity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `multiple subscripts mixed types each evaluated`() {
        let source = """
            struct Buffer<let N: Int> {
                subscript(raw: Int) -> Element { fatalError() }
                subscript(bounded: Index<Element>.Bounded<N>) -> Element { fatalError() }
                subscript(other: Int) -> Bool { false }
            }
            """
        let findings = Lint.Rule.`bounded index static capacity Tests`.findings(in: source)
        // Two raw-Int subscripts flagged; the bounded one not.
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`bounded index static capacity Tests`.`Edge Case` {
    @Test
    func `an extension in another file of a value-generic type is checked`() {
        let declaring = "public struct Inset<let N: Int> {}"
        let index = Lint.Source.Index.collect(from: Parser.parse(source: declaring))
        let parsed = Lint.Source.parsed(
            from: "extension Inset { public subscript(axis: Int) -> Int { 0 } }",
            file: "Sources/Inset/Inset+Subscript.swift",
            index: index
        )
        let findings = Lint.Rule.`bounded index static capacity`.observe(parsed, .warning).findings
        #expect(findings.count == 1)
    }
}
