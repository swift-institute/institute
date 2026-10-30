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
    struct `extension noncopyable constraint Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`extension noncopyable constraint Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "Sources/X/Test.swift"
    )
        -> [Diagnostic.Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`extension noncopyable constraint`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`extension noncopyable constraint Tests`.Unit {
    @Test
    func `extension with consuming method but no constraint is flagged`() {
        let source = """
            extension Container<Element> {
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension with consuming method and noncopyable constraint is permitted`() {
        let source = """
            extension Container where Element: ~Copyable {
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with no ownership-affecting members is not flagged`() {
        let source = """
            extension Container<Element> {
                func describe() -> String { "" }
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with borrowing method but no constraint is flagged`() {
        let source = """
            extension Container<Element> {
                borrowing func peek() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension with consuming parameter but no constraint is flagged`() {
        let source = """
            extension Pipe<Token> {
                func push(_ token: consuming Token) {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    // swiftlint:disable:next function_name_whitespace
    func
        `extension with where clause containing noncopyable on a different generic param is permitted`()
    {
        let source = """
            extension Pair where Left: ~Copyable {
                consuming func split() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `where clause whose comment mentions tilde-Copyable but does not suppress it still fires`() {
        // #25 defect 7: the previous textual `.contains("~Copyable")`
        // check matched inside a comment; the structural
        // `memoryWhereClauseHasNoncopyable` check must not.
        let source = """
            extension Container<Element> where T: /* ~Copyable later */ Sendable {
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension on namespace containing nested type with consuming init is not flagged`() {
        let source = """
            extension Ownership {
                struct Indirect<Value: ~Copyable>: ~Copyable {
                    init(consuming value: consuming Value) {}
                }
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on namespace containing nested type with consuming method is not flagged`() {
        let source = """
            extension Ownership {
                struct Latch<Value: ~Copyable>: ~Copyable {
                    consuming func take() -> Value { fatalError() }
                }
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    // swiftlint:disable:next function_name_whitespace
    func
        `extension on namespace with both nested type and own consuming method flags only the latter`()
    {
        let source = """
            extension Container<Element> {
                struct Inner<T: ~Copyable>: ~Copyable {
                    init(consuming value: consuming T) {}
                }
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // #25 defect 8: the five fixtures below previously extended a
    // SYNTACTICALLY NON-GENERIC target (`extension Ownership.Transfer.
    // Erased.Incoming { ... }`, `extension Box { ... }`), which
    // `extensionTargetIsSyntacticallyNonGeneric` exempts BEFORE the
    // ownership finder ever runs — so each fixture's `isEmpty`
    // assertion held for the wrong reason and never reached the
    // method-local-generic machinery its name claims to exercise.
    // Rewritten to extend a syntactically generic target so the
    // ownership finder — and its method-local-generic exemption —
    // actually runs.

    @Test
    func `method-local generic consuming parameter on a generic extension is not flagged`() {
        let source = """
            extension Pool<Resource> {
                func consume<T>(_ value: consuming T) {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `method-local generic borrowing parameter on a generic extension is not flagged`() {
        let source = """
            extension Pool<Resource> {
                func inspect<T>(_ value: borrowing T) {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `method-local generic init consuming parameter on a generic extension is not flagged`() {
        let source = """
            extension Box<Element> {
                init<T>(consuming value: consuming T) {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with consuming parameter whose type is not method-local is still flagged`() {
        let source = """
            extension Pool<Resource> {
                func take<T>(_ resource: consuming Resource) {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `consuming-self method with own generic params on a generic extension is not flagged`() {
        let source = """
            extension Pool<Resource> {
                public consuming func consume<T>(_ type: T.Type) -> T { fatalError() }
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `borrowing-self method with own generic params on a generic extension is not flagged`() {
        let source = """
            extension Pool<Resource> {
                public borrowing func inspect<T>(_ type: T.Type) -> Bool { false }
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `consuming-self method whose parameter carries a non-generic ownership type still fires`() {
        // #25 defect 7: even though the self-modifier is method-scoped
        // (own generic params), a parameter carrying a `consuming`/
        // `borrowing` specifier whose type is NOT one of the function's
        // own generics is type-level ownership and must still fire.
        let source = """
            extension Pool<Resource> {
                public consuming func replace<T>(_ next: consuming Resource, tag: T) {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `consuming-self method without own generic params is still flagged`() {
        let source = """
            extension Container<Element> {
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Exemption shape: [RULE-EXEMPT-1] (positive-Copyable). Author has
    // explicitly scoped the extension to a Copyable surface; the
    // "silent shrink to Copyable" premise is inverted by the explicit
    // conformance and the rule MUST NOT fire.

    @Test
    func `extension with positive Copyable constraint is exempt per RULE-EXEMPT-1`() {
        let source = """
            extension Container where Element: Copyable {
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with composition positive Copyable constraint is exempt per RULE-EXEMPT-1`() {
        let source = """
            extension Container where Element: SomeProtocol & Copyable {
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with Swift-qualified positive Copyable constraint is exempt per RULE-EXEMPT-1`() {
        let source = """
            extension Container where Element: Swift.Copyable {
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Exemption shape: syntactic non-generic detection. The rule's
    // premise — "extension on `~Copyable`-aware GENERIC type implicitly
    // constrains to Copyable, silently shrinking the surface" — applies
    // only when the extension target IS generic. For syntactically-
    // non-generic targets (no `<...>`, no where clause), the where
    // clause is structurally inexpressible and the rule MUST NOT fire.
    // Scales automatically to new directly-`~Copyable` types without
    // per-type allowlist maintenance.

    @Test
    func `extension on bare non-generic leaf is exempt via syntactic detection`() {
        let source = """
            extension Comparison {
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on qualified non-generic type is exempt via syntactic detection`() {
        let source = """
            extension Affine.Discrete.Vector {
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on directly-Noncopyable type is exempt via syntactic detection`() {
        // Lint.Source.Parsed is `~Copyable, Sendable` at L1 per the
        // Tier-2 RECOMMENDATION v1.1.0 (2026-05-13). Extensions carry
        // `borrowing func` methods; the rule's `where ~Copyable` request
        // is structurally inexpressible (no generic parameter exists).
        let source = """
            extension Lint.Source.Parsed {
                borrowing func visibility(at position: Int) -> Int { 0 }
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Ordinal leaf is not flagged regression check`() {
        let source = """
            extension Ordinal {
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on explicit-generic-form of bare leaf still fires`() {
        // Demonstrates that the syntactic detection's discriminator is
        // presence of `<...>` (not the type's leaf name). An author who
        // writes the explicit-parameter form of a generic type without
        // a where clause IS subject to the rule's premise.
        let source = """
            extension Vector<Element> {
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // #25 defect 9: untested risky exemptions — each was an unbounded
    // silent hole with zero coverage before this pass.

    @Test
    func `repeat each T pack expansion usage is exempt`() {
        let source = """
            extension Bundle<Element> {
                func combine<each T>(_ value: consuming Element, _ values: repeat each T) {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `bare each T without repeat each T is NOT pack-exempt`() {
        // Pins that `PackExpansionTypeSyntax`/`PackElementTypeSyntax` are
        // the node kinds the finder actually looks for — a generic
        // parameter clause spelled `<each T>` with no `repeat each T`
        // usage anywhere in the body does not trip the exemption. Uses a
        // non-self ownership signal (a `consuming` parameter, not a
        // `consuming func`) so the method-local-generic self-modifier
        // exemption cannot itself explain a zero-finding result.
        let source = """
            extension Bundle<Element> {
                func combine<each T>(_ value: consuming Element) {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `stdlib allowlist leaf Array is exempt`() {
        let source = """
            extension Array<Element> {
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `filename with the where discriminator is exempt`() {
        let source = """
            extension Container<Element> {
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(
            in: source,
            file: "Sources/X/Container where Element is Sendable.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `filename without the where discriminator still fires`() {
        let source = """
            extension Container<Element> {
                consuming func transfer() {}
            }
            """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(
            in: source,
            file: "Sources/X/Container.swift"
        )
        #expect(findings.count == 1)
    }
}
