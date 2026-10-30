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
    struct `pointer advanced by Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`pointer advanced by Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "Sources/test.swift"
    )
        -> [Diagnostic.Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`pointer advanced by`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`pointer advanced by Tests`.Unit {
    @Test
    func `unsafe advanced by call is flagged`() {
        let source = """
            func op(_ ptr: UnsafePointer<Int>, offset: Int) {
                let next = unsafe ptr.advanced(by: offset)
                use(next)
            }
            """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "pointer advanced by")
        }
    }

    @Test
    func `multiple unsafe advanced by calls each flagged`() {
        let source = """
            func op(_ ptr: UnsafePointer<Int>, a: Int, b: Int) {
                let p1 = unsafe ptr.advanced(by: a)
                let p2 = unsafe ptr.advanced(by: b)
                use(p1, p2)
            }
            """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`pointer advanced by Tests`.`Edge Case` {
    /// THE range regression test: `Strideable.advanced(by:)` over a range's
    /// `Bound` is a safe stdlib op (no `unsafe`) and MUST NOT fire. This is
    /// the false-positive class that swift-range' 8 findings were.
    @Test
    func `Strideable advanced by without unsafe is NOT flagged`() {
        let source = """
            func op(_ range: Range<Int>) {
                var i = range.lowerBound
                while i < range.upperBound {
                    use(i)
                    i = i.advanced(by: 1)
                }
            }
            """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unrelated method named advance is NOT flagged`() {
        let source = """
            func op(_ x: Foo) {
                let next = x.removeFirst(1)
                use(next)
            }
            """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `advanced without by label is NOT flagged`() {
        let source = """
            func op(_ x: Foo) {
                let next = unsafe x.advanced(2)
                use(next)
            }
            """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `pointer at typed primitive call is NOT flagged`() {
        let source = """
            func op(_ storage: Storage, slot: Int) {
                let p = storage.pointer(at: slot)
                use(p)
            }
            """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    /// Tests / Experiments / Examples trees legitimately exercise pointer
    /// arithmetic against the typed SLI overloads.
    @Test
    func `unsafe advanced by under Tests path is NOT flagged`() {
        let source = """
            func op(_ ptr: UnsafePointer<Int>, n: Int) {
                let next = unsafe ptr.advanced(by: n)
                use(next)
            }
            """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(
            in: source,
            file: "Tests/Memory Tests/Memory Arithmetic Tests.swift"
        )
        #expect(findings.isEmpty)
    }

    /// A documented last-resort site (adjacent `// SAFETY:`) is exempt.
    @Test
    func `last-resort unsafe advanced by with SAFETY comment is NOT flagged`() {
        let source = """
            func op(_ ptr: UnsafeMutableRawPointer, n: Int) {
                // SAFETY: last resort — move-out semantics MutableSpan cannot express
                let p = unsafe ptr.advanced(by: n)
                use(p)
            }
            """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    /// A `// SAFETY:` comment followed by a doc comment before the site is
    /// still adjacent — a doc comment is content, not a break.
    @Test
    func `last-resort unsafe advanced by with SAFETY comment then doc comment is NOT flagged`() {
        let source = """
            func op(_ ptr: UnsafeMutableRawPointer, n: Int) {
                // SAFETY: last resort — move-out semantics MutableSpan cannot express
                /// Advances past the header.
                let p = unsafe ptr.advanced(by: n)
                use(p)
            }
            """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    /// The same site WITHOUT the justification comment DOES fire — proving the
    /// exemption keys on the comment, not on the `unsafe` keyword alone.
    @Test
    func `last-resort unsafe advanced by without SAFETY comment IS flagged`() {
        let source = """
            func op(_ ptr: UnsafeMutableRawPointer, n: Int) {
                let p = unsafe ptr.advanced(by: n)
                use(p)
            }
            """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    /// #25 defect 9 remainder: the `// WHY:` prefix is an alternate
    /// justification spelling to `// SAFETY:`, previously untested.
    @Test
    func `last-resort unsafe advanced by with WHY comment is NOT flagged`() {
        let source = """
            func op(_ ptr: UnsafeMutableRawPointer, n: Int) {
                // WHY: MutableSpan cannot express move-out semantics here
                let p = unsafe ptr.advanced(by: n)
                use(p)
            }
            """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    /// #25 defect 9 remainder: the `Experiments/` path exclusion,
    /// previously untested (only `Tests/` was covered).
    @Test
    func `unsafe advanced by under Experiments path is NOT flagged`() {
        let source = """
            func op(_ ptr: UnsafePointer<Int>, n: Int) {
                let next = unsafe ptr.advanced(by: n)
                use(next)
            }
            """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(
            in: source,
            file: "Experiments/Memory Arithmetic/Sandbox.swift"
        )
        #expect(findings.isEmpty)
    }

    /// #25 defect 9 remainder: the `Examples/` path exclusion, previously
    /// untested.
    @Test
    func `unsafe advanced by under Examples path is NOT flagged`() {
        let source = """
            func op(_ ptr: UnsafePointer<Int>, n: Int) {
                let next = unsafe ptr.advanced(by: n)
                use(next)
            }
            """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(
            in: source,
            file: "Examples/Memory Arithmetic/Demo.swift"
        )
        #expect(findings.isEmpty)
    }
}
