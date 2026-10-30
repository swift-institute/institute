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
    struct `safe attribute undocumented Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct `Admit with disclosure` {}
        @Suite struct `Fire without disclosure` {}
        @Suite struct `Decl kinds` {}
        @Suite struct `Adjacency edges` {}
        @Suite struct Scope {}
    }
}

extension Lint.Rule.`safe attribute undocumented Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "Sources/X/Test.swift"
    )
        -> [Diagnostic.Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`safe attribute undocumented`.observe(parsed, .warning).findings
    }
}

// MARK: - Admit with disclosure (no finding)
//
// Per the Option B DECISION (2026-05-12): `@safe` is admitted on any
// declaration in `Sources/` provided an adjacent invariant disclosure
// is present. The disclosure can be a `// SAFETY:` / `// WHY:` line
// block OR a `## Safety Invariant` doc-comment section.

extension Lint.Rule.`safe attribute undocumented Tests`.`Admit with disclosure` {

    @Test
    func `safe struct with WHY Category line is admitted`() {
        // Standard absorber pattern: `@safe public struct` + adjacent
        // `// WHY: Category <X>` block.
        let source = """
            // WHY: Category A — synchronized via internal lock; see [MEM-SAFE-024].
            @safe
            public struct LockedState {
                private let lock = Lock()
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe struct with SAFETY line (no Category) is admitted`() {
        // Per [MEM-SAFE-025c], Category citation is SHOULD-strength —
        // a free-form `// SAFETY:` block without Category citation is
        // accepted when the site isn't categorizable under A/B/C/D.
        let source = """
            // SAFETY: Transitive absorption of `Ownership.Borrow<Base>`; the
            // SAFETY: wrapper's API never exposes the underlying borrow as a
            // SAFETY: raw pointer, and `~Escapable` prevents lifetime escape.
            @safe
            public struct Borrow {
                private let inner: Int
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe struct with Safety Invariant doc section is admitted`() {
        // Disclosure form (b) — `## Safety Invariant` in a `///`
        // doc-comment.
        let source = """
            /// Internal storage class.
            ///
            /// ## Safety Invariant
            /// Pointer allocated once at init and never reassigned. COW discipline
            /// ensures unique ownership per isolation domain. See [MEM-SAFE-024].
            @safe
            final class _Storage {
                let buffer: UnsafePointer<UInt8>
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe struct with disclosure BETWEEN attr and keyword is admitted`() {
        // Ecosystem ordering: `@safe` line first, then `// WHY:` block,
        // then `public struct …`. The disclosure is in the leading
        // trivia of `public`, not of `@`; the predicate must scan each
        // token's trivia separately.
        let source = """
            @safe
            // WHY: Category D — structural Sendable workaround (SP-5).
            // WHY: Buffer is a Copyable descriptor; stored fields are pure
            // WHY: value bytes; @unchecked Sendable bridges inference gap.
            public struct Buffer: @unchecked Sendable {
                private let _start: Int
                private let _count: Int
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe struct on cluster B shape (transitive) with disclosure is admitted`() {
        // Cluster B (transitive absorber): no direct unsafe markers in
        // the file, but `@safe` documents transitive absorption
        // through a wrapped type. Under the previous rule, the
        // condition-1 check would reject this; the inverted rule
        // admits it on the strength of the disclosure alone.
        let source = """
            // SAFETY: Transitive absorption of `Ownership.Borrow<Base>`; the
            // SAFETY: outer wrapper inherits its inner's invariants.
            @safe
            public struct Property {
                private let inner: Int
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe struct on cluster C shape (pure documentation) with disclosure is admitted`() {
        // Cluster C (pure-documentation absorber): no unsafe markers at
        // all. `@safe` is a documentation signal. The inverted rule
        // admits this — disclosure presence is the only requirement.
        let source = """
            // SAFETY: Safe by construction — backing storage is `InlineArray`,
            // SAFETY: which is itself fully safe; `@safe` is a documentation
            // SAFETY: marker that this type performs no unsafe operations.
            @safe
            public struct Inline {
                private let storage: Int
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe struct with WHY block then non-invariant line within block is admitted`() {
        // The institute idiom mixes invariant disclosure with metadata
        // comments (`// WHEN TO REMOVE:`, `// TRACKING:`). Such non-
        // invariant lines within the adjacent block are tolerated.
        let source = """
            // WHY: Category D — pointer-backed.
            // WHEN TO REMOVE: when SE-XXXX lands.
            @safe
            public struct Container {
                private let raw: Int
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe struct with lowercase keyword in disclosure is admitted`() {
        // Case-insensitive on the keyword — `safety:` and `why:` are
        // accepted as well as `SAFETY:` / `WHY:`.
        let source = """
            // safety: lowercase keyword is also valid.
            @safe
            public struct Lowered {
                private let raw: Int
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

// MARK: - Fire without disclosure (finding emitted)

extension Lint.Rule.`safe attribute undocumented Tests`.`Fire without disclosure` {

    @Test
    func `safe struct with no comment fires`() {
        // `@safe` on a bare struct with no adjacent invariant
        // disclosure — finding fires.
        let source = """
            @safe
            public struct Padded {}
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe struct with non-adjacent comment fires`() {
        // A blank line between the disclosure and the decl breaks
        // adjacency — the rule fires.
        let source = """
            // SAFETY: Allocated once at init.

            @safe
            public struct Far {
                private let raw: Int
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe struct with whitespace-only blank line between disclosure and decl fires`() {
        // Regression guard: a blank line consisting only of horizontal
        // whitespace (`// SAFETY: …\n␠␠\n@safe`) is still a blank-line
        // break — two newline-like trivia pieces separated only by
        // spaces/tabs must accumulate exactly like a single `newlines(2)`
        // piece would, not reset per-piece and silently admit. Built via
        // explicit `\n` + literal spaces (not a triple-quoted literal) so
        // the whitespace-only line survives formatting.
        let source =
            "// SAFETY: Allocated once at init.\n  \n@safe\npublic struct Far {\n    private let raw: Int\n}"
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe struct with non-invariant comment only fires`() {
        // A `// TODO:` or other unrelated comment doesn't satisfy the
        // disclosure requirement.
        let source = """
            // TODO: re-evaluate this annotation.
            @safe
            public struct Loose {
                private let raw: Int
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe struct with non-adjacent doc section fires`() {
        // Doc-comment block separated by a blank line from the decl
        // is not adjacent.
        let source = """
            /// ## Safety Invariant
            /// Allocated once at init.

            @safe
            public struct Disjoint {
                private let raw: Int
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple bare safe attributes are each flagged`() {
        // Each undisclosed `@safe` site emits its own finding.
        let source = """
            @safe
            public struct A {}

            @safe
            public struct B {}
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

// MARK: - All declaration kinds admitted under [MEM-SAFE-025b]
//
// Per disposition #2 of the Option B DECISION, `@safe` is admitted on
// every declaration form SE-0458 permits, not just type declarations.
// These tests confirm the inverted rule treats all decl kinds uniformly.

extension Lint.Rule.`safe attribute undocumented Tests`.`Decl kinds` {

    @Test
    func `safe class with disclosure is admitted`() {
        let source = """
            // WHY: Category A — synchronized.
            @safe
            final class _Storage {}
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe actor with disclosure is admitted`() {
        let source = """
            // WHY: Category A — actor isolation.
            @safe
            public actor Coordinator {}
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe enum with disclosure is admitted`() {
        let source = """
            // WHY: Category D — SP-5 pointer payload.
            @safe
            public enum Token {
                case raw(Int)
                case empty
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe extension with disclosure is admitted`() {
        // The previous rule flagged `@safe` on extensions
        // unconditionally; the inverted rule admits them on the
        // strength of disclosure.
        let source = """
            // WHY: Category A — synchronized externally.
            @safe
            extension MyType: @unchecked Sendable {}
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe function with disclosure is admitted`() {
        // Per disposition #2, methods are admitted with disclosure.
        let source = """
            // SAFETY: Bounds-checked at every call site.
            @safe
            func doWork() {}
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe variable with disclosure is admitted`() {
        // Per disposition #2, properties / lets / vars are admitted.
        let source = """
            // SAFETY: Allocated once at module init; pointee never mutated.
            @safe @usableFromInline
            nonisolated(unsafe) let _sentinel: Int = 0
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe initializer with disclosure is admitted`() {
        // Per disposition #2, inits are admitted.
        let source = """
            public struct Container {
                // SAFETY: All stored fields are initialized before any
                // SAFETY: unsafe operation could observe them.
                @safe
                init() {}
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe subscript with disclosure is admitted`() {
        // Per disposition #2, subscripts are admitted.
        let source = """
            public struct Container {
                // SAFETY: Bounds-checked precondition guards every load.
                @safe
                subscript(index: Int) -> Int { 0 }
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe function without disclosure fires`() {
        // Methods without disclosure still fire. The admission is
        // conditional on disclosure presence, not on decl kind.
        let source = """
            @safe
            func doWork() {}
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe variable without disclosure fires`() {
        let source = """
            @safe @usableFromInline
            nonisolated(unsafe) let _sentinel: Int = 0
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // #25 defect 9 remainder: protocol/deinit/typealias/associatedtype
    // visitors existed but carried no coverage.

    @Test
    func `safe protocol with disclosure is admitted`() {
        let source = """
            // WHY: Category A — conformers self-certify synchronization.
            @safe
            public protocol Coordinating {}
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe protocol without disclosure fires`() {
        let source = """
            @safe
            public protocol Coordinating {}
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe deinitializer with disclosure is admitted`() {
        let source = """
            public struct Container {
                // SAFETY: Release is idempotent; double-free is unreachable.
                @safe
                deinit {}
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe deinitializer without disclosure fires`() {
        let source = """
            public struct Container {
                @safe
                deinit {}
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe typealias with disclosure is admitted`() {
        let source = """
            // WHY: Category D — SP-5 pointer payload alias.
            @safe
            public typealias RawToken = Int
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe typealias without disclosure fires`() {
        let source = """
            @safe
            public typealias RawToken = Int
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe associatedtype with disclosure is admitted`() {
        let source = """
            public protocol Coordinating {
                // WHY: Category A — conformers self-certify synchronization.
                @safe
                associatedtype Token
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe associatedtype without disclosure fires`() {
        let source = """
            public protocol Coordinating {
                @safe
                associatedtype Token
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// MARK: - Adjacency edge cases (trivia walker behavior)

extension Lint.Rule.`safe attribute undocumented Tests`.`Adjacency edges` {

    @Test
    func `no safe attribute is not flagged`() {
        // Bare declarations without `@safe` are out of scope.
        let source = """
            public struct Padded {}
            final class _Storage {}
            nonisolated(unsafe) let _sentinel: Int = 0
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unsafe attribute alone is not flagged`() {
        // `@unsafe` is governed by [MEM-SAFE-022]; this rule only
        // polices `@safe`.
        let source = """
            @unsafe
            public func raw() -> Int { 0 }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `safe struct with disclosure mixing line comments and doc section is admitted`() {
        // Both forms in the same adjacency window — either alone
        // satisfies the rule.
        let source = """
            /// ## Safety Invariant
            /// Allocated once.
            // WHY: Category D — pointer-backed.
            @safe
            public struct Both {
                private let raw: Int
            }
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`safe attribute undocumented Tests`.Scope {
    @Test
    func `safe struct with no disclosure outside Sources is NOT flagged`() {
        // The header doc and the message both assert this rule applies to
        // declarations "in Sources/" — a file outside any Sources/ path
        // component is out of scope regardless of disclosure state.
        let source = """
            @safe
            public struct Padded {}
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(
            in: source,
            file: "Tests/X/Fixture.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `safe struct with no disclosure in a nested Sources path is flagged`() {
        let source = """
            @safe
            public struct Padded {}
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(
            in: source,
            file: "Packages/Foo/Sources/Foo/Padded.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `safe struct with no disclosure at bare top-level file is NOT flagged`() {
        let source = """
            @safe
            public struct Padded {}
            """
        let findings = Lint.Rule.`safe attribute undocumented Tests`.findings(
            in: source,
            file: "script.swift"
        )
        #expect(findings.isEmpty)
    }
}
