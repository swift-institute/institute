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
    struct `binary serializable rawvalue uint8 Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`binary serializable rawvalue uint8 Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`binary serializable rawvalue uint8`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`binary serializable rawvalue uint8 Tests`.Unit {
    @Test
    func `struct with rawValue UInt8 conforming on header is flagged`() {
        let source = """
            public struct TypeOfService: Binary.Serializable {
                public let rawValue: UInt8
            }
            """
        let result = Lint.Rule.`binary serializable rawvalue uint8 Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `struct with rawValue UInt8 with conformance in extension is flagged`() {
        let source = """
            public struct TypeOfService {
                public let rawValue: UInt8
            }
            extension TypeOfService: Binary.Serializable {}
            """
        let result = Lint.Rule.`binary serializable rawvalue uint8 Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `enum with rawValue UInt8 conforming to Binary Parseable is flagged`() {
        let source = """
            public enum Foo: Binary.Parseable {
                public var rawValue: UInt8 { 0 }
            }
            """
        let result = Lint.Rule.`binary serializable rawvalue uint8 Tests`.findings(in: source)
        #expect(result.count == 1)
    }
}

extension Lint.Rule.`binary serializable rawvalue uint8 Tests`.`Edge Case` {
    @Test
    func `rawValue Byte is NOT flagged`() {
        let source = """
            public struct Flags: Binary.Serializable {
                public let rawValue: Byte
            }
            """
        let result = Lint.Rule.`binary serializable rawvalue uint8 Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `rawValue UInt16 is NOT flagged`() {
        let source = """
            public struct HeaderChecksum: Binary.Serializable {
                public let rawValue: UInt16
            }
            """
        let result = Lint.Rule.`binary serializable rawvalue uint8 Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `struct with rawValue UInt8 NOT conforming to Binary is NOT flagged`() {
        let source = """
            public struct Foo {
                public let rawValue: UInt8
            }
            """
        let result = Lint.Rule.`binary serializable rawvalue uint8 Tests`.findings(in: source)
        #expect(result.isEmpty)
    }
}

extension Lint.Rule.`binary serializable rawvalue uint8 Tests`.Integration {
    @Test
    func `multiple conformers in one file all flagged`() {
        let source = """
            public struct A: Binary.Serializable { public let rawValue: UInt8 }
            public struct B: Binary.Serializable { public let rawValue: UInt8 }
            public struct C: Binary.Serializable { public let rawValue: Byte }
            """
        let result = Lint.Rule.`binary serializable rawvalue uint8 Tests`.findings(in: source)
        #expect(result.count == 2)
    }

    @Test
    func `large file with no Binary conformers yields no findings`() {
        let source = String(repeating: "public struct X { let x: UInt8 = 0 }\n", count: 200)
        let result = Lint.Rule.`binary serializable rawvalue uint8 Tests`.findings(in: source)
        #expect(result.isEmpty)
    }
}
