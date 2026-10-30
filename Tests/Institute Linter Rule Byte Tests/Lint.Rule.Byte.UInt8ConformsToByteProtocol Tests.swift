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
    struct `uint8 conforms to byte protocol Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`uint8 conforms to byte protocol Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`uint8 conforms to byte protocol`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`uint8 conforms to byte protocol Tests`.Unit {
    @Test
    func `extension UInt8 conforming to Byte Protocol is flagged`() {
        let source = """
            extension UInt8: Byte.`Protocol` {}
            """
        let result = Lint.Rule.`uint8 conforms to byte protocol Tests`.findings(in: source)
        #expect(result.count == 1)
        if result.count == 1 {
            #expect(result[0].identifier == "uint8 conforms to byte protocol")
        }
    }

    @Test
    func `extension Swift dot UInt8 conforming to Byte Protocol is flagged`() {
        let source = """
            extension Swift.UInt8: Byte.`Protocol` {}
            """
        let result = Lint.Rule.`uint8 conforms to byte protocol Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `extension UInt8 conforming via fully-qualified Byte is flagged`() {
        let source = """
            extension UInt8: Byte.Byte.`Protocol` {}
            """
        let result = Lint.Rule.`uint8 conforms to byte protocol Tests`.findings(in: source)
        #expect(result.count == 1)
    }
}

extension Lint.Rule.`uint8 conforms to byte protocol Tests`.`Edge Case` {
    @Test
    func `extension UInt8 with no Byte Protocol conformance is NOT flagged`() {
        let source = """
            extension UInt8 {
                public var asciiUppercase: UInt8 { self & 0xDF }
            }
            """
        let result = Lint.Rule.`uint8 conforms to byte protocol Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `extension Byte conforming to Byte Protocol is NOT flagged`() {
        let source = """
            extension Byte: Byte.`Protocol` {}
            """
        let result = Lint.Rule.`uint8 conforms to byte protocol Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `extension UInt8 conforming to other protocol is NOT flagged`() {
        let source = """
            extension UInt8: Sendable {}
            """
        let result = Lint.Rule.`uint8 conforms to byte protocol Tests`.findings(in: source)
        #expect(result.isEmpty)
    }
}

extension Lint.Rule.`uint8 conforms to byte protocol Tests`.Integration {
    @Test
    func `mixed file with one violation flags exactly once`() {
        let source = """
            extension Byte: Byte.`Protocol` {}
            extension UInt8: Byte.`Protocol` {}
            extension Int: Sendable {}
            """
        let result = Lint.Rule.`uint8 conforms to byte protocol Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `large file with no violations yields no findings`() {
        let source = String(repeating: "extension Int: Sendable {}\n", count: 200)
        let result = Lint.Rule.`uint8 conforms to byte protocol Tests`.findings(in: source)
        #expect(result.isEmpty)
    }
}
