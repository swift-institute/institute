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
    struct `uint8 forwarder missing disfavored Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`uint8 forwarder missing disfavored Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`uint8 forwarder missing disfavored`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`uint8 forwarder missing disfavored Tests`.Unit {
    @Test
    func `function in extension on Byte array taking UInt8 is flagged`() {
        let source = """
            extension Array where Element == Byte {
                public func append(_ value: UInt8) {}
            }
            """
        let result = Lint.Rule.`uint8 forwarder missing disfavored Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `function on bracket-Byte returning UInt8 array is flagged`() {
        let source = """
            extension [Byte] {
                public func raw() -> [UInt8] { [] }
            }
            """
        let result = Lint.Rule.`uint8 forwarder missing disfavored Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `initializer in byte-domain extension taking UInt8 is flagged`() {
        let source = """
            extension Array where Element == Byte {
                public init(byte: UInt8) { self = [] }
            }
            """
        let result = Lint.Rule.`uint8 forwarder missing disfavored Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `protocol extension using Self dot Element equals Byte is flagged`() {
        // The idiomatic protocol-extension spelling of the byte-domain gate
        // is `where Self.Element == Byte`, which yields the requirement
        // text `Self.Element`, not bare `Element`.
        let source = """
            extension Sequence where Self.Element == Byte {
                public func append(_ value: UInt8) {}
            }
            """
        let result = Lint.Rule.`uint8 forwarder missing disfavored Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `reversed Byte equals Element gate is flagged`() {
        let source = """
            extension Array where Byte == Element {
                public func append(_ value: UInt8) {}
            }
            """
        let result = Lint.Rule.`uint8 forwarder missing disfavored Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `function returning a some Collection of UInt8 is flagged`() {
        let source = """
            extension Array where Element == Byte {
                public func raw() -> some Collection<UInt8> { [] }
            }
            """
        let result = Lint.Rule.`uint8 forwarder missing disfavored Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `function taking a UInt8 tuple parameter is flagged`() {
        let source = """
            extension Array where Element == Byte {
                public func pair(_ value: (UInt8, UInt8)) {}
            }
            """
        let result = Lint.Rule.`uint8 forwarder missing disfavored Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `function taking a UInt8 callback parameter is flagged`() {
        let source = """
            extension Array where Element == Byte {
                public func onByte(_ handler: (UInt8) -> Void) {}
            }
            """
        let result = Lint.Rule.`uint8 forwarder missing disfavored Tests`.findings(in: source)
        #expect(result.count == 1)
    }
}

extension Lint.Rule.`uint8 forwarder missing disfavored Tests`.`Edge Case` {
    @Test
    func `function with disfavored overload is NOT flagged`() {
        let source = """
            extension Array where Element == Byte {
                @_disfavoredOverload
                public func append(_ value: UInt8) {}
            }
            """
        let result = Lint.Rule.`uint8 forwarder missing disfavored Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `Byte-typed function in byte-domain extension is NOT flagged`() {
        let source = """
            extension Array where Element == Byte {
                public func append(_ value: Byte) {}
            }
            """
        let result = Lint.Rule.`uint8 forwarder missing disfavored Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `function in non-byte-domain extension taking UInt8 is NOT flagged`() {
        let source = """
            extension Array where Element == Int {
                public func append(_ value: UInt8) {}
            }
            """
        let result = Lint.Rule.`uint8 forwarder missing disfavored Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `function in extension on UInt8 array is NOT flagged`() {
        let source = """
            extension Array where Element == UInt8 {
                public func append(_ value: UInt8) {}
            }
            """
        let result = Lint.Rule.`uint8 forwarder missing disfavored Tests`.findings(in: source)
        #expect(result.isEmpty)
    }
}

extension Lint.Rule.`uint8 forwarder missing disfavored Tests`.Integration {
    @Test
    func `multiple UInt8 forwarders are all flagged independently`() {
        let source = """
            extension [Byte] {
                public func one(_ value: UInt8) {}
                public func two(_ value: UInt8) {}
                @_disfavoredOverload
                public func three(_ value: UInt8) {}
            }
            """
        let result = Lint.Rule.`uint8 forwarder missing disfavored Tests`.findings(in: source)
        #expect(result.count == 2)
    }

    @Test
    func `large file with no byte-domain extensions yields no findings`() {
        let source = String(repeating: "extension Foo { func bar() {} }\n", count: 200)
        let result = Lint.Rule.`uint8 forwarder missing disfavored Tests`.findings(in: source)
        #expect(result.isEmpty)
    }
}
