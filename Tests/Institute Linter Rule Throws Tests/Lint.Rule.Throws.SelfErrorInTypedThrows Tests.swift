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

@testable import Institute_Linter_Rule_Throws

extension Lint.Rule {
    @Suite
    struct `typed throws cannot use self error Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`typed throws cannot use self error Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`typed throws cannot use self error`.observe(parsed, .warning).findings
    }
}

// MARK: - Unit: protocol-context flagging
//
// The rule fires only for `throws(Self.Error)` inside a protocol declaration
// that does NOT declare `associatedtype Error`. In every other context
// (struct/class/enum/actor body, extension on a concrete type, protocol with
// associatedtype Error) `Self.Error` resolves correctly to a nested or
// associated type and the rule stays silent.

extension Lint.Rule.`typed throws cannot use self error Tests`.Unit {
    @Test
    func `throws Self dot Error inside protocol WITHOUT associatedtype Error is flagged`() {
        let source = """
            protocol P {
                func f() throws(Self.Error)
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "typed throws cannot use self error")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `multiple Self dot Error sites in a bare protocol are all flagged`() {
        let source = """
            protocol P {
                func a() throws(Self.Error)
                func b() throws(Self.Error)
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `async throws Self dot Error inside bare protocol is flagged`() {
        let source = """
            protocol P {
                func f() async throws(Self.Error)
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `init throws Self dot Error inside bare protocol is flagged`() {
        let source = """
            protocol P {
                init() throws(Self.Error)
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// MARK: - Edge Case: contexts where Self.Error is well-defined

extension Lint.Rule.`typed throws cannot use self error Tests`.`Edge Case` {
    @Test
    func `throws Self dot Error inside protocol declaring associatedtype Error is NOT flagged`() {
        let source = """
            protocol P {
                associatedtype Error: Swift.Error
                func f() throws(Self.Error)
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws Self dot Error in struct body is NOT flagged`() {
        let source = """
            struct S {
                func f() throws(Self.Error) -> Int { 0 }
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws Self dot Error in class body is NOT flagged`() {
        let source = """
            class C {
                func f() throws(Self.Error) -> Int { 0 }
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws Self dot Error in enum body is NOT flagged`() {
        let source = """
            enum E {
                func f() throws(Self.Error) -> Int { 0 }
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws Self dot Error in actor body is NOT flagged`() {
        let source = """
            actor A {
                func f() throws(Self.Error) -> Int { 0 }
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws Self dot Error in extension on concrete type is NOT flagged`() {
        let source = """
            extension Random {
                func generate() throws(Self.Error) -> UInt64 { 0 }
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws Self dot Error in noncopyable consuming method is NOT flagged`() {
        let source = """
            extension Storage.Pool {
                consuming func release() throws(Self.Error) { }
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws fully nested error is NOT flagged`() {
        let source = """
            extension Random {
                func generate() throws(Random.Error) -> UInt64 { 0 }
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws three level nested error is NOT flagged`() {
        let source = """
            extension Storage.Pool {
                func acquire() throws(Storage.Pool.Error) { }
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `bare throws is NOT flagged`() {
        let source = "func f() throws -> Int { 0 }"
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-throwing function is NOT flagged`() {
        let source = "func f() -> Int { 0 }"
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws any Error is NOT flagged by this rule`() {
        // swiftlint:disable:next no_existential_throws
        let source = "func f() throws(any Error) -> Int { 0 }"
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws Self dot OtherError is NOT flagged`() {
        let source = """
            struct S {
                func f() throws(Self.OtherError) -> Int { 0 }
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws domain dot Error is NOT flagged`() {
        let source = """
            struct S {
                func f() throws(Foo.Error) -> Int { 0 }
            }
            """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Self dot Error in a string literal is NOT flagged`() {
        let source = "let s = \"throws(Self.Error)\""
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
