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
    struct `nonisolated unsafe without invariant Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`nonisolated unsafe without invariant Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "Sources/X/Test.swift"
    )
        -> [Diagnostic.Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`nonisolated unsafe without invariant`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`nonisolated unsafe without invariant Tests`.Unit {
    @Test
    func `nonisolated unsafe without comment is flagged`() {
        let source = """
            nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nonisolated unsafe with adjacent SAFETY comment is permitted`() {
        let source = """
            // SAFETY: Allocated once at module init; pointee never mutated.
            nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nonisolated unsafe with adjacent WHY comment is permitted`() {
        let source = """
            // WHY: Category D (SP-5) — UnsafeRawPointer blocks structural Sendable.
            nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nonisolated unsafe with multi-line SAFETY block is permitted`() {
        let source = """
            // SAFETY: Allocated once at module init; pointee never mutated post-init.
            // SAFETY: Used as sentinel for empty-buffer comparison only.
            @usableFromInline
            nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `SAFETY comment followed by a doc comment before the declaration is permitted`() {
        let source = """
            // SAFETY: Allocated once at module init; pointee never mutated.
            /// The buffer's sentinel value.
            nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-adjacent SAFETY comment is flagged`() {
        let source = """
            // SAFETY: Allocated once at module init.

            nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-SAFETY comment adjacent is flagged`() {
        let source = """
            // This is a sentinel value used by the empty buffer check.
            nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nonisolated without unsafe is not flagged`() {
        let source = """
            nonisolated let value: Int = 0
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `regular let is not flagged`() {
        let source = """
            let value: Int = 0
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nonisolated unsafe var without comment is flagged`() {
        let source = """
            nonisolated(unsafe) var counter: Int = 0
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nonisolated unsafe var with SAFETY comment is permitted`() {
        let source = """
            // SAFETY: Mutated only on the main thread under MainActor isolation.
            nonisolated(unsafe) var counter: Int = 0
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `doc comment alone does not satisfy adjacency`() {
        // Doc comments are for API surface; the institute uses `// SAFETY:` / `// WHY:`
        // for the encapsulation invariant. A doc comment alone fires.
        let source = """
            /// Module-level sentinel used by Memory.Buffer empty-state checks.
            nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multi-line SAFETY block with first-line-only prefix is permitted`() {
        // First-line-prefix convention: the // SAFETY: prefix on the
        // FIRST line of a contiguous comment block suffices; continuation
        // lines without the prefix are accepted as part of the same block.
        let source = """
            // SAFETY: Mutated only on the main thread under MainActor isolation.
            // The annotation marks the local as disconnected from the caller's
            // region; downstream reads are serialized by the actor.
            nonisolated(unsafe) var counter: Int = 0
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `multi-line WHY block with first-line-only prefix is permitted`() {
        // Parity with SAFETY for the WHY prefix.
        let source = """
            // WHY: established ecosystem pattern; the binding is load-bearing
            // because nonisolated(unsafe) is a declaration modifier.
            nonisolated(unsafe) let v = value
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `swift-linter disable directive between SAFETY and declaration is walked through`() {
        // The directive line doesn't carry SAFETY/WHY but is still inside
        // the contiguous comment block. The walker should treat it as a
        // pass-through, finding the SAFETY line earlier in the block.
        let source = """
            // SAFETY: Mutated only under MainActor isolation.
            // swift-linter:disable:next intermediate binding then return
            nonisolated(unsafe) let v = value
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `blank line between SAFETY and declaration breaks adjacency`() {
        // Regression guard: the contiguous-block requirement holds.
        let source = """
            // SAFETY: Mutated only on the main thread under MainActor isolation.

            nonisolated(unsafe) var counter: Int = 0
            """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `CRLF blank line between SAFETY and declaration breaks adjacency`() {
        // Regression guard: `.carriageReturnLineFeeds(2)` (a blank line in
        // a CRLF-line-ended file) must break adjacency exactly like
        // `.newlines(2)` does. Built explicitly with `\r\n` rather than a
        // triple-quoted literal so the CRLF sequence survives formatting.
        let source =
            "// SAFETY: Mutated only on the main thread under MainActor isolation.\r\n\r\nnonisolated(unsafe) var counter: Int = 0"
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
