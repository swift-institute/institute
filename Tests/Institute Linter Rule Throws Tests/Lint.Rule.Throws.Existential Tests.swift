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
    struct `existential throws Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`existential throws Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`existential throws`.observe(parsed, .warning).findings
    }
}

// swiftlint:disable no_existential_throws
// REASON: this suite's fixture sources deliberately embed `throws(any Error)` as
// the string literal under test — self-referential fixture shape (rule-exemptions
// skill); the regex-based no_existential_throws rule cannot distinguish a fixture
// string from live code. Re-enabled at end of file.
extension Lint.Rule.`existential throws Tests`.Unit {
    @Test
    func `throws any Error is flagged`() {
        let source = "func f() throws(any Error) -> Int { 0 }"
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "existential throws")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `throws any Swift dot Error is flagged`() {
        let source = "func f() throws(any Swift.Error) -> Int { 0 }"
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple existential throws are all flagged`() {
        let source = """
            func a() throws(any Error) {}
            func b() throws(any Swift.Error) {}
            """
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `async throws any Error is flagged`() {
        let source = "func f() async throws(any Error) -> Int { 0 }"
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `init throws any Error is flagged`() {
        let source = """
            struct S {
                init() throws(any Error) {}
            }
            """
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `closure type with throws any Error is flagged`() {
        let source = "let f: () throws(any Error) -> Int = { 0 }"
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`existential throws Tests`.`Edge Case` {
    @Test
    func `throws(SpecificError) is NOT flagged`() {
        let source = """
            struct E: Swift.Error {}
            func f() throws(E) -> Int { 0 }
            """
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `bare throws is NOT flagged`() {
        let source = "func f() throws -> Int { 0 }"
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws(any OtherProtocol) is NOT flagged`() {
        let source = """
            protocol P {}
            func f() throws(any P) -> Int { 0 }
            """
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `existential throws in a string literal is NOT flagged`() {
        let source = "let s = \"throws(any Error)\""
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-throwing function is NOT flagged`() {
        let source = "func f() -> Int { 0 }"
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Exemption shape: [RULE-EXEMPT-2] (protocol-witness-citation-dict).
    // `init(from:)` inside a Decodable / Codable conformance and
    // `encode(to:)` inside an Encodable / Codable conformance carry
    // the protocol's untyped `throws` signature; the conformer cannot
    // narrow it. Tuple-valued dict lets one witness satisfy multiple
    // protocols.

    @Test
    func `init from inside Decodable conformance is exempt per RULE-EXEMPT-2`() {
        let source = """
            extension MyType: Decodable {
                public init(from decoder: any Decoder) throws(any Error) { fatalError() }
            }
            """
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `encode to inside Encodable conformance is exempt per RULE-EXEMPT-2`() {
        let source = """
            extension MyType: Encodable {
                public func encode(to encoder: any Encoder) throws(any Error) { fatalError() }
            }
            """
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `init from in a bare extension is exempt via the canonical witness signature`() {
        // #19 defect 2, item 3: the bare-extension fallback keyed off the
        // witness key (a sole `Decoder` parameter), not the protocol list —
        // the `// MARK: - Codable` pattern where the conformance is declared
        // in a separate extension/file from the witness. This replaces the
        // prior assertion here, which pinned the wrong (pre-fix) behavior.
        let source = """
            extension MyType {
                public init(from decoder: any Decoder) throws(any Error) { fatalError() }
            }
            """
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `init from on the declaring type itself (not an extension) is exempt`() {
        // Conformance-site parity: `struct Foo: Decodable { init(from:) throws(any Error) }`
        // — conformance on the TYPE rather than an extension — must be exempt,
        // matching `untyped throws`'s behavior for the same shape.
        let source = """
            struct Foo: Decodable {
                init(from decoder: any Decoder) throws(any Error) { fatalError() }
            }
            """
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested helper inside a Decodable witness still fires`() {
        // Signature-position restriction (item 2): the exemption applies to
        // the WITNESS's own signature only. A nested function inside the
        // witness body is ordinary code and still fires.
        let source = """
            extension MyType: Decodable {
                public init(from decoder: any Decoder) throws {
                    func helper() throws(any Error) {}
                    try helper()
                }
            }
            """
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // MARK: - #require macro carve-out

    @Test
    func `function using require macro is NOT flagged for throws any Error`() {
        // Carve-out: swift-testing's `#require` macro expands to
        // `try Testing.__check(...).__required()` which throws
        // `any Error` by macro contract. No concrete public error
        // type is exposed for the throws clause; the existential is
        // structurally required.
        let source = """
            func `unwraps optional`() throws(any Error) {
                let value = try #require(maybeValue)
                #expect(value == 42)
            }
            """
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `init using require macro is NOT flagged for throws any Error`() {
        let source = """
            struct S {
                init() throws(any Error) {
                    let value = try #require(possibly)
                    self.value = value
                }
            }
            """
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `function without require macro is still flagged for throws any Error`() {
        // Regression guard: the carve-out is gated on the macro's
        // actual presence in the function body. A function that uses
        // some OTHER api but declares throws(any Error) still fires.
        let source = """
            func `does not use require`() throws(any Error) {
                try otherCall()
            }
            """
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `function calling a different macro is still flagged`() {
        // Regression guard: only `#require` triggers the carve-out.
        // Other macros (like `#expect`) don't force the existential
        // (their throws contract is different).
        let source = """
            func `uses expect`() throws(any Error) {
                #expect(value == 42)
            }
            """
        let findings = Lint.Rule.`existential throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
// swiftlint:enable no_existential_throws
