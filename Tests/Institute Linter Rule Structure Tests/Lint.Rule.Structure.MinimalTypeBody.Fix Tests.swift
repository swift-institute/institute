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
import Linter_Rule_Testing
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Institute_Linter_Rule_Structure

extension Lint.Rule {
    @Suite
    struct `minimal type body fix Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct `Round Trip` {}
        @Suite struct `Not Fixable` {}
    }
}

extension Lint.Rule.`minimal type body fix Tests` {
    static func fixed(_ source: String, file: String = "test.swift") -> String? {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`minimal type body`.rewritten(parsed)
    }

    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`minimal type body`.observe(parsed, .warning).findings
    }

    /// The self-round-trip property: flagged before, rewritten, parses, and
    /// silent afterwards.
    static func roundTrips(
        _ source: String,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        #expect(
            !findings(in: source).isEmpty,
            "fixture must fire before it can round-trip",
            sourceLocation: sourceLocation
        )
        guard let output = fixed(source) else {
            Issue.record("expected a rewrite", sourceLocation: sourceLocation)
            return
        }
        #expect(
            !Parser.parse(source: output).hasError,
            "rewrite must parse: \(output)",
            sourceLocation: sourceLocation
        )
        #expect(
            findings(in: output).isEmpty,
            "rewrite must re-lint clean: \(output)",
            sourceLocation: sourceLocation
        )
    }

    /// Asserts the rule fires but the fix declines to rewrite — the finding
    /// stands for a person.
    static func declines(
        _ source: String,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        #expect(!findings(in: source).isEmpty, sourceLocation: sourceLocation)
        #expect(fixed(source) == nil, sourceLocation: sourceLocation)
    }
}

extension Lint.Rule.`minimal type body fix Tests`.`Round Trip` {
    @Test
    func `a method moves to a same-file extension`() {
        let source = """
            struct Buffer {
                var x: Int
                func append(_ value: Int) {}
            }
            """
        Lint.Rule.`minimal type body fix Tests`.roundTrips(source)
        let output = Lint.Rule.`minimal type body fix Tests`.fixed(source)
        #expect(output?.contains("extension Buffer") == true)
        #expect(output?.contains("func append(_ value: Int) {}") == true)
    }

    @Test
    func `a private stored property stays mutually visible to a moved method`() {
        // The moved method reads a `private` stored property left behind in
        // the primary body. Swift extends `private` to same-file extensions of
        // the declaring type, and the generated extension is emitted into
        // THIS SAME file — verified independently against the toolchain via
        // `swiftc -typecheck` for this exact shape (struct + private stored
        // property + init + a moved method reading it).
        let source = """
            struct Box {
                private var storage: Int
                init(storage: Int) {
                    self.storage = storage
                }
                func doubled() -> Int {
                    storage * 2
                }
            }
            """
        Lint.Rule.`minimal type body fix Tests`.roundTrips(source)
        let output = Lint.Rule.`minimal type body fix Tests`.fixed(source)
        #expect(output?.contains("private var storage: Int") == true)
        #expect(output?.contains("extension Box") == true)
        #expect(output?.contains("func doubled() -> Int") == true)
    }

    @Test
    func `an enum's computed property and static member move to a same-file extension`() {
        let source = """
            enum State {
                case idle
                case running
                var isIdle: Bool { self == .idle }
                static let `default` = State.idle
            }
            """
        Lint.Rule.`minimal type body fix Tests`.roundTrips(source)
        let output = Lint.Rule.`minimal type body fix Tests`.fixed(source)
        #expect(output?.contains("extension State") == true)
        #expect(output?.contains("case idle") == true)
        #expect(output?.contains("var isIdle: Bool") == true)
    }

    @Test
    func `a nested type with only stored properties moves as a whole unit`() {
        // The nested type itself carries no violation of its own (only stored
        // properties), so moving it whole leaves nothing further to fix.
        let source = """
            struct Outer {
                var x: Int
                struct Inner {
                    let y: Int
                }
            }
            """
        Lint.Rule.`minimal type body fix Tests`.roundTrips(source)
        let output = Lint.Rule.`minimal type body fix Tests`.fixed(source)
        #expect(output?.contains("extension Outer") == true)
        #expect(output?.contains("struct Inner") == true)
    }

    @Test
    func `every movable member kind in one struct lands in the extension`() {
        let source = """
            struct Kitchen {
                var x: Int
                func f() {}
                var computed: Int { x }
                static let shared = 0
                subscript(i: Int) -> Int { i }
                typealias Alias = Int
                struct Nested { let z: Int }
                protocol Requirement { var q: Int { get } }
            }
            """
        Lint.Rule.`minimal type body fix Tests`.roundTrips(source)
        let output = Lint.Rule.`minimal type body fix Tests`.fixed(source)
        #expect(output?.contains("extension Kitchen") == true)
        #expect(output?.contains("func f() {}") == true)
        #expect(output?.contains("var computed: Int { x }") == true)
        #expect(output?.contains("static let shared = 0") == true)
        #expect(output?.contains("subscript(i: Int) -> Int { i }") == true)
        #expect(output?.contains("typealias Alias = Int") == true)
        #expect(output?.contains("struct Nested") == true)
        #expect(output?.contains("protocol Requirement") == true)
    }

    @Test
    func `a struct in a top-level extension is fixed via a qualified path`() {
        let source = """
            extension Lint.Rule {
                struct `Foo Tests` {
                    var x: Int
                    func run() {}
                }
            }
            """
        Lint.Rule.`minimal type body fix Tests`.roundTrips(source)
        let output = Lint.Rule.`minimal type body fix Tests`.fixed(source)
        #expect(output?.contains("extension Lint.Rule.`Foo Tests`") == true)
        #expect(output?.contains("func run() {}") == true)
    }

    @Test
    func `an already-minimal struct is not rewritten`() {
        let source = """
            struct Buffer {
                var x: Int
                init(x: Int) { self.x = x }
            }
            """
        #expect(Lint.Rule.`minimal type body fix Tests`.findings(in: source).isEmpty)
        #expect(Lint.Rule.`minimal type body fix Tests`.fixed(source) == nil)
    }
}

extension Lint.Rule.`minimal type body fix Tests`.`Not Fixable` {
    @Test
    func `a class is never rewritten - dispatch semantics refusal`() {
        // [API-IMPL-008] fix precondition: a method in a class body is
        // dynamically dispatched; the same method in an extension is not.
        // The finding stands; the fix refuses outright, with no partial
        // application.
        Lint.Rule.`minimal type body fix Tests`.declines(
            """
            class Box {
                var x: Int = 0
                func doubled() -> Int { x * 2 }
            }
            """
        )
    }

    @Test
    func `an actor is never rewritten - dispatch semantics refusal`() {
        Lint.Rule.`minimal type body fix Tests`.declines(
            """
            actor Box {
                var x: Int = 0
                func doubled() -> Int { x * 2 }
            }
            """
        )
    }

    @Test
    func `a class with movable members does not block an unrelated top-level struct's fix`() {
        // The refusal is per-declaration, not whole-file: a class's own
        // members are never touched, but a struct elsewhere in the SAME file
        // is still fixed, and the class's finding remains standing in the
        // rewritten output.
        let source = """
            class Skipped {
                var x: Int = 0
                func doubled() -> Int { x * 2 }
            }

            struct Fixed {
                var y: Int
                func tripled() -> Int { y * 3 }
            }
            """
        #expect(Lint.Rule.`minimal type body fix Tests`.findings(in: source).count == 2)
        guard let output = Lint.Rule.`minimal type body fix Tests`.fixed(source) else {
            Issue.record("expected a partial rewrite")
            return
        }
        #expect(!Parser.parse(source: output).hasError)
        #expect(output.contains("extension Fixed"))
        #expect(output.contains("func tripled() -> Int { y * 3 }"))
        // The class's own method is untouched — still inside `class Skipped`,
        // not moved to an extension — and its finding still fires.
        let remaining = Lint.Rule.`minimal type body fix Tests`.findings(in: output)
        #expect(remaining.count == 1)
        if remaining.count == 1 {
            #expect(remaining[0].identifier == "minimal type body")
        }
    }

    @Test
    func `a value type nested inside a class body is out of this fix's narrower scope`() {
        // Deliberately narrower than the detector: the fix only ever emits a
        // TOP-LEVEL extension, referenced through at most one enclosing
        // `extension` ancestor. A struct nested inside a class body (a
        // genuine nominal-type ancestor, not an extension) is left as a
        // standing finding rather than guessed at.
        Lint.Rule.`minimal type body fix Tests`.declines(
            """
            class Outer {
                struct Inner {
                    var x: Int
                    func f() {}
                }
            }
            """
        )
    }

    @Test
    func `a struct nested inside another struct is out of this fix's narrower scope`() {
        Lint.Rule.`minimal type body fix Tests`.declines(
            """
            struct Outer {
                struct Inner {
                    var x: Int
                    func f() {}
                }
            }
            """
        )
    }

    @Test
    func `an if-guarded member is flagged but declined - unconditional-extension safety`() {
        // The detector splices `#if` clauses and still flags what's inside
        // them, but moving only the inner declaration out from under its
        // `#if` guard would silently drop the conditional-compilation
        // boundary the author wrote. The fix leaves it exactly as found.
        Lint.Rule.`minimal type body fix Tests`.declines(
            """
            struct Foo {
                var x: Int
                #if os(Linux)
                func f() {}
                #endif
            }
            """
        )
    }

    @Test
    func `an if-guarded member does not block an unrelated movable member in the same type`() {
        // Partial application WITHIN one type body: the plain method moves,
        // the `#if`-guarded one is left behind, and its finding still fires
        // in the rewritten output — this is not a round-trip case.
        let source = """
            struct Foo {
                var x: Int
                func plain() {}
                #if os(Linux)
                func guarded() {}
                #endif
            }
            """
        #expect(Lint.Rule.`minimal type body fix Tests`.findings(in: source).count == 2)
        guard let output = Lint.Rule.`minimal type body fix Tests`.fixed(source) else {
            Issue.record("expected a partial rewrite")
            return
        }
        #expect(!Parser.parse(source: output).hasError)
        #expect(output.contains("extension Foo"))
        #expect(output.contains("func plain() {}"))
        #expect(output.contains("#if os(Linux)"))
        #expect(output.contains("func guarded() {}"))
        let remaining = Lint.Rule.`minimal type body fix Tests`.findings(in: output)
        #expect(remaining.count == 1)
    }

    @Test
    func `a resultBuilder-exempt type is not rewritten`() {
        let source = """
            @resultBuilder
            enum MyBuilder {
                static func buildBlock(_ x: Int) -> Int { x }
            }
            """
        #expect(Lint.Rule.`minimal type body fix Tests`.findings(in: source).isEmpty)
        #expect(Lint.Rule.`minimal type body fix Tests`.fixed(source) == nil)
    }

    @Test
    func `a Suite-exempt type is not rewritten`() {
        let source = """
            @Suite
            struct `Outer Suite` {
                @Suite struct Unit {}
            }
            """
        #expect(Lint.Rule.`minimal type body fix Tests`.findings(in: source).isEmpty)
        #expect(Lint.Rule.`minimal type body fix Tests`.fixed(source) == nil)
    }

    @Test
    func `an @available struct is never rewritten - the generated extension carries no attribute`() {
        // The generated extension has no attribute list at all, so
        // `extension Widget { ... }` for `@available(macOS 15, *) struct
        // Widget` fails to compile: 'Widget' is only available in macOS 15
        // or newer. Refusal, not attribute propagation — see the class/actor
        // refusal for the same asymmetry argument.
        Lint.Rule.`minimal type body fix Tests`.declines(
            """
            @available(macOS 15, *)
            struct Widget {
                var x: Int
                func doubled() -> Int { x * 2 }
            }
            """
        )
    }

    @Test
    func `@available inherited from an enclosing extension also refuses - house idiom`() {
        // The repository's own idiom: `extension Lint.Rule { @available(...)
        // struct \`X Tests\` { ... } }`. `Inner` carries no attribute of its
        // own, so a predicate reading only the declaration's own attributes
        // would miss this; the enclosing extension ancestor this fix already
        // climbs must be checked too, or `extension Parent.Inner { ... }`
        // would compile-fail identically to the direct-attribute case.
        Lint.Rule.`minimal type body fix Tests`.declines(
            """
            @available(macOS 15, *)
            extension Parent {
                struct Inner {
                    var x: Int
                    func doubled() -> Int { x * 2 }
                }
            }
            """
        )
    }

    @Test
    func `an @available struct does not block an unrelated top-level struct's fix`() {
        // Partial application across the file: the refusal is per-declaration,
        // not whole-file. The unattributed struct elsewhere in the same file
        // is still fixed, and the @available struct's finding remains
        // standing in the rewritten output.
        let source = """
            @available(macOS 15, *)
            struct Skipped {
                var x: Int
                func doubled() -> Int { x * 2 }
            }

            struct Fixed {
                var y: Int
                func tripled() -> Int { y * 3 }
            }
            """
        #expect(Lint.Rule.`minimal type body fix Tests`.findings(in: source).count == 2)
        guard let output = Lint.Rule.`minimal type body fix Tests`.fixed(source) else {
            Issue.record("expected a partial rewrite")
            return
        }
        #expect(!Parser.parse(source: output).hasError)
        #expect(output.contains("extension Fixed"))
        #expect(output.contains("func tripled() -> Int { y * 3 }"))
        // The @available struct's own method is untouched, and its finding
        // still fires.
        let remaining = Lint.Rule.`minimal type body fix Tests`.findings(in: output)
        #expect(remaining.count == 1)
        if remaining.count == 1 {
            #expect(remaining[0].identifier == "minimal type body")
        }
    }
}
