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

@testable import Institute_Linter_Rule_Byte

extension Lint.Rule {
    @Suite
    struct `byte conforms to arithmetic protocol Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`byte conforms to arithmetic protocol Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`byte conforms to arithmetic protocol`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`byte conforms to arithmetic protocol Tests`.Unit {
    @Test
    func `Byte conforming to AdditiveArithmetic is flagged`() {
        let source = """
            extension Byte: AdditiveArithmetic {}
            """
        let result = Lint.Rule.`byte conforms to arithmetic protocol Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `Byte conforming to Numeric is flagged`() {
        let source = """
            extension Byte: Numeric {}
            """
        let result = Lint.Rule.`byte conforms to arithmetic protocol Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `Byte conforming to BinaryInteger is flagged`() {
        let source = """
            extension Byte: BinaryInteger {}
            """
        let result = Lint.Rule.`byte conforms to arithmetic protocol Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `Byte conforming to FixedWidthInteger is flagged`() {
        let source = """
            extension Byte: FixedWidthInteger {}
            """
        let result = Lint.Rule.`byte conforms to arithmetic protocol Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `Byte conforming to Strideable is flagged`() {
        let source = """
            extension Byte: Strideable {}
            """
        let result = Lint.Rule.`byte conforms to arithmetic protocol Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `Byte primary declaration conforming to AdditiveArithmetic is flagged`() {
        // `Byte` is a real struct declaration — the conformance can be
        // adopted directly on the primary declaration, not only via a
        // later `extension`.
        let source = """
            public struct Byte: AdditiveArithmetic {}
            """
        let result = Lint.Rule.`byte conforms to arithmetic protocol Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `Byte-qualified extension conforming to Numeric is flagged`() {
        let source = """
            extension Byte.Byte: Numeric {}
            """
        let result = Lint.Rule.`byte conforms to arithmetic protocol Tests`.findings(in: source)
        #expect(result.count == 1)
    }
}

extension Lint.Rule.`byte conforms to arithmetic protocol Tests`.`Edge Case` {
    @Test
    func `unrelated namespace's nested Byte type is NOT flagged`() {
        // `RFC_1234.Byte` is an unrelated nested type in a consumer
        // namespace, not `Byte.Byte` — the rule must not accept
        // any qualified type whose leaf happens to be `Byte`.
        let source = """
            extension RFC_1234.Byte: AdditiveArithmetic {}
            """
        let result = Lint.Rule.`byte conforms to arithmetic protocol Tests`.findings(in: source)
        #expect(result.isEmpty)
    }
}

extension Lint.Rule.`byte conforms to arithmetic protocol Tests`.`Edge Case` {
    @Test
    func `Byte conforming to Equatable Hashable Comparable is NOT flagged`() {
        let source = """
            extension Byte: Equatable {}
            extension Byte: Hashable {}
            extension Byte: Comparable {}
            extension Byte: Sendable {}
            extension Byte: Codable {}
            extension Byte: CustomStringConvertible {}
            """
        let result = Lint.Rule.`byte conforms to arithmetic protocol Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `UInt8 conforming to BinaryInteger is NOT flagged`() {
        // Rule scoped to Byte; UInt8 already conforms in stdlib.
        let source = """
            extension UInt8: BinaryInteger {}
            """
        let result = Lint.Rule.`byte conforms to arithmetic protocol Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `Byte conforming via Swift dot Numeric is flagged`() {
        let source = """
            extension Byte: Swift.Numeric {}
            """
        let result = Lint.Rule.`byte conforms to arithmetic protocol Tests`.findings(in: source)
        #expect(result.count == 1)
    }
}

extension Lint.Rule.`byte conforms to arithmetic protocol Tests`.Integration {
    @Test
    func `multiple arithmetic conformances in one extension fire per-protocol`() {
        let source = """
            extension Byte: AdditiveArithmetic, Numeric {}
            """
        let result = Lint.Rule.`byte conforms to arithmetic protocol Tests`.findings(in: source)
        #expect(result.count == 2)
    }

    @Test
    func `large file with byte-domain conformances yields no findings`() {
        let source = String(repeating: "extension Byte: Equatable {}\n", count: 200)
        let result = Lint.Rule.`byte conforms to arithmetic protocol Tests`.findings(in: source)
        #expect(result.isEmpty)
    }
}
