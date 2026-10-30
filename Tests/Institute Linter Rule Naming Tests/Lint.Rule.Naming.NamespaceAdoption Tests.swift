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
    struct `namespace adoption typealias Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`namespace adoption typealias Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        let rule = Lint.Rule.`namespace adoption typealias`
        return rule.observe(parsed, rule.severity.default).findings
    }
}

extension Lint.Rule.`namespace adoption typealias Tests`.Unit {
    @Test
    func `same-leaf typealias is flagged for review`() {
        let source = """
            public typealias Event = Kernel.Event
            """
        let rule = Lint.Rule.`namespace adoption typealias`
        #expect(rule.severity.default == .note)
        let findings = Lint.Rule.`namespace adoption typealias Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "namespace adoption typealias")
            #expect(findings[0].severity == .note)
        }
    }

    @Test
    func `deeper same-leaf typealias is flagged`() {
        let source = """
            public typealias Channel = Kernel.IO.Channel
            """
        let findings = Lint.Rule.`namespace adoption typealias Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `pure passthrough generic typealias IS still flagged`() {
        // Every RHS argument is a bare forward of an LHS generic parameter
        // (no Self-type binding) — a pure rename bridge, still flagged.
        let source = """
            extension MyNamespace {
                public typealias Array<T> = Swift.Array<T>
            }
            """
        let findings = Lint.Rule.`namespace adoption typealias Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`namespace adoption typealias Tests`.`Edge Case` {
    @Test
    func `different-leaf typealias is NOT flagged`() {
        let source = """
            public typealias SourceLocation = Text.Location
            """
        let findings = Lint.Rule.`namespace adoption typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-member-type RHS is NOT flagged`() {
        let source = """
            public typealias Foo = Int
            """
        let findings = Lint.Rule.`namespace adoption typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `associatedtype satisfier in conforming extension is NOT flagged`() {
        // `extension X: Y { typealias Z = W.Z }` declares conformance to `Y`;
        // the same-leaf typealias is satisfying an associatedtype requirement
        // of `Y`, not a discretionary namespace-adoption choice.
        let source = """
            extension Tagged: Collection where Underlying: Collection {
                public typealias Index = Underlying.Index
            }
            """
        let findings = Lint.Rule.`namespace adoption typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `associatedtype satisfier in conforming type body is NOT flagged`() {
        let source = """
            public struct Tagged: Collection {
                public typealias Index = Int
            }
            """
        let findings = Lint.Rule.`namespace adoption typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `same-leaf typealias in plain extension IS still flagged`() {
        // Extension WITHOUT an inheritance clause is not introducing a
        // protocol conformance — the same-leaf typealias is a rename
        // bridge, not an associatedtype satisfier.
        let source = """
            extension Tagged {
                public typealias Event = Kernel.Event
            }
            """
        let findings = Lint.Rule.`namespace adoption typealias Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `parameterized adoption binding the enclosing type is NOT flagged`() {
        // The institute consumer-adoption idiom: a generic typealias that
        // forwards its own parameter (Tag) AND binds the enclosing Self-type
        // (Stack<Element>) into the underlying two-parameter generic. This is
        // a partial application, not a rename bridge.
        let source = """
            extension Stack {
                public typealias Property<Tag> =
                    Property.Property<Tag, Stack<Element>>
            }
            """
        let findings = Lint.Rule.`namespace adoption typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `parameterized adoption binding a concrete type is NOT flagged`() {
        // Forwarding the parameter while binding a concrete type argument is
        // also partial application, not a rename.
        let source = """
            extension Box {
                public typealias Property<Tag> =
                    Property.Property<Tag, Int>
            }
            """
        let findings = Lint.Rule.`namespace adoption typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
