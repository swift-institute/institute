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
    struct `convention c representability Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`convention c representability Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`convention c representability`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`convention c representability Tests`.Unit {
    @Test
    func `convention c with UnsafeMutablePointer to qualified type is flagged`() {
        let source = """
            let cb: @convention(c) (UnsafeMutablePointer<Kernel.Signal.Information>?) -> Void = { _ in }
            """
        let findings = Lint.Rule.`convention c representability Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "convention c representability")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `convention c with UnsafePointer to qualified type is flagged`() {
        let source = """
            let cb: @convention(c) (UnsafePointer<Foo.Bar>?) -> Void = { _ in }
            """
        let findings = Lint.Rule.`convention c representability Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `convention c with UnsafeMutablePointer to bare Swift struct is flagged`() {
        // Regression guard: the documented case — a bare (unqualified)
        // Swift-defined struct — previously went undetected because the
        // predicate only matched a qualified `MemberTypeSyntax` pointee.
        let source = """
            let cb: @convention(c) (UnsafeMutablePointer<MyStruct>?) -> Void = { _ in }
            """
        let findings = Lint.Rule.`convention c representability Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple unsafe-pointer-to-qualified parameters each flagged`() {
        let source = """
            let cb: @convention(c) (UnsafeMutablePointer<Foo.Bar>?, UnsafeMutablePointer<Baz.Qux>?) -> Void = { _, _ in }
            """
        let findings = Lint.Rule.`convention c representability Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`convention c representability Tests`.`Edge Case` {
    @Test
    func `convention c with OpaquePointer is NOT flagged`() {
        let source = """
            let cb: @convention(c) (OpaquePointer?) -> Void = { _ in }
            """
        let findings = Lint.Rule.`convention c representability Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `convention c with UnsafeMutableRawPointer is NOT flagged`() {
        let source = """
            let cb: @convention(c) (UnsafeMutableRawPointer?) -> Void = { _ in }
            """
        let findings = Lint.Rule.`convention c representability Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `convention c with UnsafeMutablePointer to primitive Int32 is NOT flagged`() {
        let source = """
            let cb: @convention(c) (UnsafeMutablePointer<Int32>?) -> Void = { _ in }
            """
        let findings = Lint.Rule.`convention c representability Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `convention c with UnsafeMutablePointer to Int32Wrapper (near-miss) is flagged`() {
        // "Int32Wrapper" merely resembles a stdlib primitive by name; it is
        // not one of the closed set's exact spellings (#34), so it remains a
        // Swift-defined struct and the rule MUST still fire. Proves the
        // exemption matches by exact name, not by prefix/substring.
        let source = """
            let cb: @convention(c) (UnsafeMutablePointer<Int32Wrapper>?) -> Void = { _ in }
            """
        let findings = Lint.Rule.`convention c representability Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-convention-c function type with same pointer is NOT flagged`() {
        let source = """
            let cb: (UnsafeMutablePointer<Foo.Bar>?) -> Void = { _ in }
            """
        let findings = Lint.Rule.`convention c representability Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `convention swift with qualified pointer is NOT flagged`() {
        let source = """
            let cb: @convention(swift) (UnsafeMutablePointer<Foo.Bar>?) -> Void = { _ in }
            """
        let findings = Lint.Rule.`convention c representability Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `convention c with UnsafeMutablePointer to Darwin-qualified C struct is NOT flagged`() {
        // Regression guard: a C struct reached through its module
        // qualifier (`Darwin.kevent`) is perfectly C-representable — and
        // module-qualified spelling is the house style in exactly the
        // platform code this rule targets. Previously flagged as a false
        // positive because any `MemberTypeSyntax`-shaped pointee matched.
        let source = """
            let cb: @convention(c) (UnsafeMutablePointer<Darwin.kevent>?) -> Void = { _ in }
            """
        let findings = Lint.Rule.`convention c representability Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `convention c with UnsafeMutablePointer to Glibc-qualified C struct is NOT flagged`() {
        let source = """
            let cb: @convention(c) (UnsafeMutablePointer<Glibc.stat>?) -> Void = { _ in }
            """
        let findings = Lint.Rule.`convention c representability Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `convention c with cType variant is also matched`() {
        let source = """
            let cb: @convention(c, cType: "void (*)(int *)") (UnsafeMutablePointer<Foo.Bar>?) -> Void = { _ in }
            """
        let findings = Lint.Rule.`convention c representability Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
