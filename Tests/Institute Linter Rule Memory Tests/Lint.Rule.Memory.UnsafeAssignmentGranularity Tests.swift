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
    struct `unsafe assignment granularity Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`unsafe assignment granularity Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`unsafe assignment granularity`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`unsafe assignment granularity Tests`.Unit {
    @Test
    func `pointee-destination assignment with RHS-only unsafe is flagged`() {
        let source = """
            func op() {
                self.raw.pointee = unsafe Unmanaged.passRetained(x).toOpaque()
            }
            """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "unsafe assignment granularity")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `pointee assignment with RHS-only unsafe is flagged`() {
        // The destination is a `.pointee` store — an unsafe destination — so
        // the RHS-only `unsafe` leaves it uncovered.
        let source = """
            func op() {
                pointer.pointee = unsafe other.pointee
            }
            """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `pointer subscript assignment with RHS-only unsafe is flagged`() {
        let source = """
            func op() {
                pointer[i] = unsafe other.pointee
            }
            """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple offending assignments each flagged`() {
        let source = """
            func op() {
                pointer.pointee = unsafe x.deref()
                pointer[0].pointee = unsafe y.deref()
            }
            """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`unsafe assignment granularity Tests`.`Edge Case` {
    @Test
    func `unsafe wrapping entire assignment is NOT flagged`() {
        let source = """
            func op() {
                unsafe (self.raw.pointee = Unmanaged.passRetained(x).toOpaque())
            }
            """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `assignment to a safe destination with an unsafe RHS is NOT flagged`() {
        // The classic SE-0458 shape: `count = unsafe pointer.pointee`. The
        // destination `count` is plain safe storage — already fully covered
        // by the RHS's own `unsafe` acknowledgment of the load. Only the
        // destination determines whether the rule should widen the region.
        let source = """
            func op() {
                count = unsafe pointer.pointee
            }
            """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `assignment to an unannotated subscript with an unsafe RHS is NOT flagged`() {
        // `buffer[i]` gives no syntactic signal that the destination is
        // unsafe storage (it could equally be an Array/InlineArray element) —
        // without a pointer-shaped base, the rule must not assume the
        // destination needs covering.
        let source = """
            func op() {
                buffer[i] = unsafe pointer.pointee
            }
            """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unsafe-destination assignment with LHS also unsafe-wrapped is NOT flagged`() {
        // `unsafe pointer.pointee = unsafe other.pointee` — the destination's
        // own `.pointee` access is separately acknowledged by its own leading
        // `unsafe` keyword (SwiftParser attaches `unsafe` to the whole LHS
        // member-access chain, not just its base). Expression granularity is
        // satisfied independently on both sides, so nothing is left uncovered.
        let source = """
            func op() {
                unsafe pointer.pointee = unsafe other.pointee
            }
            """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `let binding with unsafe initializer is NOT flagged`() {
        // Binding-initializer is a different shape from assignment; the
        // `let` boundary covers the destination implicitly.
        let source = """
            func op() {
                let x = unsafe pointer.pointee
            }
            """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `bare unsafe expression is NOT flagged`() {
        let source = """
            func op() {
                unsafe pointer.pointee
            }
            """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `assignment with non-unsafe RHS is NOT flagged`() {
        let source = """
            func op() {
                self.a = 0
                self.b = compute()
            }
            """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `var binding with unsafe initializer is NOT flagged`() {
        let source = """
            func op() {
                var x = unsafe pointer.pointee
                x = 0
            }
            """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
