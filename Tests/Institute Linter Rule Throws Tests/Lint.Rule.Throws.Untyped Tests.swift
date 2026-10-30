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
    struct `untyped throws Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`untyped throws Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`untyped throws`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`untyped throws Tests`.Unit {
    @Test
    func `bare throws is flagged`() {
        let source = "func f() throws -> Int { 0 }"
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "untyped throws")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `async throws is flagged`() {
        let source = "func f() async throws -> Int { 0 }"
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `throws inside protocol declaration is flagged`() {
        let source = """
            protocol P {
                func f() throws -> Int
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple untyped throws are all flagged`() {
        let source = """
            func a() throws {}
            func b() throws -> Int { 0 }
            func c() async throws -> String { "" }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 3)
    }

    @Test
    func `init throws is flagged`() {
        let source = """
            struct S {
                init() throws {}
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `closure type with bare throws is flagged`() {
        let source = "let f: () throws -> Int = { 0 }"
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`untyped throws Tests`.`Edge Case` {
    @Test
    func `throws(SomeError) is NOT flagged`() {
        let source = """
            struct E: Swift.Error {}
            func f() throws(E) -> Int { 0 }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-throwing function is NOT flagged`() {
        let source = "func f() -> Int { 0 }"
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `rethrows is NOT flagged`() {
        let source = "func map<T>(_ f: () throws -> T) rethrows -> T { try f() }"
        // The rule targets `throws` clauses only; the `rethrows` keyword is a different
        // syntax node. The argument-position `() throws -> T` is itself a bare-throws
        // closure type, however, which the rule DOES flag.
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `throws keyword in a string literal is NOT flagged`() {
        let source = "let s = \"func f() throws -> Int\""
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `empty file produces no findings`() {
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }

    @Test
    func `extension method with throws is flagged`() {
        let source = """
            extension Int {
                func compute() throws -> Int { self }
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // §C3 — external-protocol conformance allowlist (Testing.TestScoping.provideScope).

    @Test
    func `provideScope in a TestScoping conformance is NOT flagged`() {
        let source = """
            extension Foo: Testing.TestScoping {
                public func provideScope(
                    for test: Testing.Test,
                    testCase: Testing.Test.Case?,
                    performing function: @Sendable () async throws -> Void
                ) async throws {
                    try await function()
                }
            }
            """
        // Both signature-position untyped throws (outer `async throws` and the
        // `performing` closure type) are conformance-forced → exempt.
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `provideScope in a multi-conformance (SuiteTrait, TestScoping) is NOT flagged`() {
        let source = """
            extension Foo: Testing.SuiteTrait, Testing.TestScoping {
                public func provideScope(performing function: @Sendable () async -> Void) async throws {
                    await function()
                }
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `provideScope outside a TestScoping conformance IS flagged`() {
        let source = """
            extension Foo {
                func provideScope() async throws {}
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `differently-named method in a TestScoping conformance IS flagged`() {
        let source = """
            extension Foo: Testing.TestScoping {
                func somethingElse() throws {}
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `untyped throws in a provideScope body is still flagged`() {
        let source = """
            extension Foo: Testing.TestScoping {
                public func provideScope(performing function: @Sendable () async -> Void) async throws {
                    func helper() throws {}
                    try helper()
                    await function()
                }
            }
            """
        // The outer `async throws` is exempt (signature); the body-local
        // `func helper() throws` is NOT forced by the protocol → still fires.
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // §C3 — Codable witness pair (Encodable.encode(to:), Decodable.init(from:)),
    // added by the remediation arc per Table A #3.

    @Test
    func `encode(to:) in an Encodable conformance is NOT flagged`() {
        let source = """
            extension Foo: Encodable {
                public func encode(to encoder: any Encoder) throws {
                    var container = encoder.singleValueContainer()
                }
            }
            """
        // Signature-position `throws` is conformance-forced by Encodable → exempt.
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `init(from:) in a Decodable conformance is NOT flagged`() {
        let source = """
            extension Foo: Decodable {
                public init(from decoder: any Decoder) throws {
                    let container = try decoder.singleValueContainer()
                }
            }
            """
        // The initializer's signature-position `throws` is conformance-forced → exempt.
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Codable witnesses in a bare extension are NOT flagged`() {
        // The dominant real-world shape (e.g. swift-rfc-9110 `HTTP.Headers.swift`):
        // the conformance is declared elsewhere; this extension only provides the
        // witnesses and carries NO inheritance clause. Recognized by signature shape
        // (sole `Decoder`/`Encoder` parameter), not by an enclosing conformance.
        let source = """
            extension Foo {
                public init(from decoder: any Decoder) throws {
                    let container = try decoder.singleValueContainer()
                }
                public func encode(to encoder: any Encoder) throws {
                    var container = encoder.singleValueContainer()
                }
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Codable witnesses in a composed Codable conformance are NOT flagged`() {
        let source = """
            extension Foo: Codable {
                public init(from decoder: any Decoder) throws {}
                public func encode(to encoder: any Encoder) throws {}
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `untyped throws in an encode(to:) body is still flagged`() {
        let source = """
            extension Foo {
                public func encode(to encoder: any Encoder) throws {
                    func helper() throws {}
                    try helper()
                }
            }
            """
        // The signature `throws` is exempt; the body-local `func helper() throws`
        // is not conformance-forced → still fires.
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `untyped throws in an init(from:) body is still flagged`() {
        let source = """
            extension Foo {
                public init(from decoder: any Decoder) throws {
                    func helper() throws {}
                    try helper()
                    self.init()
                }
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `a non-witness init(from:) with a non-Decoder parameter IS flagged`() {
        // Precision: signature-shape recognition must not over-exempt. A bare
        // `init(from:)` whose parameter is not a `Decoder` is not a Codable witness.
        let source = """
            extension Foo {
                public init(from text: String) throws {}
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `a non-witness encode with no parameter IS flagged`() {
        let source = """
            extension Foo {
                public func encode() throws {}
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// #16 Option C ledger, Entry III.c (DECISION 2026-07-23): @Test /
// @Suite-member declarations are exempt — a test rethrows to the runner
// and has no API surface.
extension Lint.Rule.`untyped throws Tests`.`Edge Case` {
    @Test
    func `untyped throws on a Test function is NOT flagged`() {
        let source = """
            @Suite struct `Widget Tests` {
                @Test
                func `round-trips`() async throws {
                    try await run()
                }
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `untyped throws on a Suite-member helper is NOT flagged`() {
        let source = """
            @Suite(.serialized) enum Tests {
                static func makeServer() async throws -> Server {
                    try await Server()
                }
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `untyped throws in extension of same-file Suite type is NOT flagged`() {
        // The [SWIFT-TEST-002] extension-pattern: `@Suite enum Tests {}`
        // nested via extension, members hung on a sibling extension.
        let source = """
            extension Sockets.TCP.Listener {
                @Suite(.serialized)
                enum Tests {}
            }

            extension Sockets.TCP.Listener.Tests {
                static func makeServer() async throws -> Server {
                    try await Server()
                }
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `untyped throws on a plain function is still flagged after III-c`() {
        // Positive control: file-scope helpers (even in test files) keep
        // firing — they have callers and can adopt typed throws.
        let source = """
            private func serverSideEcho(listener: Listener) async throws -> [UInt8] {
                try await listener.echo()
            }
            """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
