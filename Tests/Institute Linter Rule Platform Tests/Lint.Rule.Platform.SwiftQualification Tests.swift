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

@testable import Institute_Linter_Rule_Platform

extension Lint.Rule {
    @Suite
    struct `swift protocol qualification Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`swift protocol qualification Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`swift protocol qualification`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`swift protocol qualification Tests`.Unit {
    @Test
    func `bare some Sequence parameter is flagged`() {
        let source = "func consume(_ bytes: some Sequence<UInt8>) {}"
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "swift protocol qualification")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `bare Error generic constraint is flagged`() {
        let source = "func parse<E: Error>() throws(E) {}"
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `bare Error conformance is flagged`() {
        let source = "enum State: Error {}"
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `bare Sequence in where-clause is flagged`() {
        let source = """
            extension Foo where T: Sequence {
                func bar() {}
            }
            """
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `bare Collection conformance is flagged`() {
        let source = "struct Buffer: Collection {}"
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `composition with bare Sequence flags Sequence only`() {
        // `some Sequence & Sendable` — Sequence flagged, Sendable is not
        // in the shadowed set.
        let source = "func consume(_ bytes: some Sequence & Sendable) {}"
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple bare references are all flagged`() {
        let source = """
            func a<T: Sequence>(_ x: T) {}
            func b<E: Error>(_ x: E) {}
            struct C: Collection {}
            """
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.count == 3)
    }
}

extension Lint.Rule.`swift protocol qualification Tests`.`Edge Case` {
    @Test
    func `qualified Swift dot Sequence is NOT flagged`() {
        let source = "func consume(_ bytes: some Swift.Sequence<UInt8>) {}"
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `qualified Swift dot Error generic constraint is NOT flagged`() {
        let source = "func parse<E: Swift.Error>() throws(E) {}"
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `member-type MyDomain dot Error throws is NOT flagged`() {
        // `MyDomain.Error` is the project's typed-throws leaf, not the
        // stdlib `Swift.Error` protocol bare. Member-type access is OK.
        let source = "func op() throws(MyDomain.Error) {}"
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-shadowed protocol Hashable conformance is NOT flagged`() {
        let source = "struct Foo: Hashable {}"
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Sendable in composition is NOT flagged`() {
        // Sendable is not in the shadowed set (no institute namespace
        // collision). It's exempt.
        let source = "func consume(_ bytes: some Sendable) {}"
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Variable binding type Sequence is NOT flagged`() {
        // Out of mechanical scope per rule body (variable bindings).
        let source = "let x: Sequence = fatalError() as Never"
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `function-return-type Sequence in non-some position is NOT flagged`() {
        // Plain return-type position (not some/any) is out of scope —
        // typically the type wouldn't even compile (Sequence is a PAT).
        // Document the boundary as edge case.
        let source = "func op() -> Sequence { fatalError() }"
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Exemption shape: [RULE-EXEMPT-6] (stdlib-shadow). Inside an
    // extension on a stdlib type, the `Swift.<Protocol>` form is
    // structurally inexpressible — Swift name resolution treats the
    // bare `Swift` identifier as the type's nested scope.

    @Test
    func `Sequence inside Array extension is exempt per RULE-EXEMPT-6`() {
        let source = """
            extension Array {
                func process<T>(_ items: some Sequence<T>) {}
            }
            """
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Sequence inside Dictionary extension is exempt per RULE-EXEMPT-6`() {
        let source = """
            extension Dictionary {
                func process<T>(_ items: some Sequence<T>) {}
            }
            """
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Sequence outside stdlib extension is still flagged`() {
        // Negative case — the same bare `Sequence` outside an extension
        // on a stdlib type is structurally expressible as `Swift.Sequence`,
        // so the rule MUST still fire.
        let source = """
            extension MyType {
                func process<T>(_ items: some Sequence<T>) {}
            }
            """
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // #21 defect 14: the `MemberTypeSyntax` arm of the stdlib-shadow
    // check must verify the extended type actually IS the stdlib type
    // (qualified `Swift.Array`), not merely share a leaf name with one.

    @Test
    func `Sequence inside qualified Swift dot Array extension is exempt`() {
        let source = """
            extension Swift.Array {
                func process<T>(_ items: some Sequence<T>) {}
            }
            """
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Sequence inside foreign namespace dot Set extension still fires`() {
        // `MyNamespace.Set` shares the leaf name `Set` with the stdlib
        // type but is not it — the exemption must not apply.
        let source = """
            extension MyNamespace.Set {
                func process<T>(_ items: some Sequence<T>) {}
            }
            """
        let findings = Lint.Rule.`swift protocol qualification Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
