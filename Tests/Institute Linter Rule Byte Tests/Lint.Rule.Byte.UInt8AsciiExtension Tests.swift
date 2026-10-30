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
    struct `uint8 ascii extension Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`uint8 ascii extension Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`uint8 ascii extension`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`uint8 ascii extension Tests`.Unit {
    @Test
    func `extension UInt8 dot ASCII is flagged`() {
        let source = """
            extension UInt8.ASCII {
                public static let lf: UInt8 = 0x0A
            }
            """
        let result = Lint.Rule.`uint8 ascii extension Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `extension UInt8 with static var ascii is flagged`() {
        let source = """
            extension UInt8 {
                public static var ascii: Self { 0 }
            }
            """
        let result = Lint.Rule.`uint8 ascii extension Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `extension UInt8 with nested ASCII enum is flagged`() {
        let source = """
            extension UInt8 {
                public enum ASCII {
                    public static let lf: UInt8 = 0x0A
                }
            }
            """
        let result = Lint.Rule.`uint8 ascii extension Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    // MARK: - #23 nit 5: decl-kind coverage and visibility indifference

    @Test
    func `extension UInt8 with nested ASCII class is flagged`() {
        let source = """
            extension UInt8 {
                public class ASCII {}
            }
            """
        let result = Lint.Rule.`uint8 ascii extension Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `extension UInt8 with nested ASCII actor is flagged`() {
        let source = """
            extension UInt8 {
                actor ASCII {}
            }
            """
        let result = Lint.Rule.`uint8 ascii extension Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `extension UInt8 with ASCII typealias is flagged`() {
        let source = """
            extension UInt8 {
                typealias ASCII = ASCIINamespace
            }
            """
        let result = Lint.Rule.`uint8 ascii extension Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `non-public static var ascii is still flagged`() {
        // The rule is about namespace shape, not visibility.
        let source = """
            extension UInt8 {
                static var ascii: Int { 0 }
            }
            """
        let result = Lint.Rule.`uint8 ascii extension Tests`.findings(in: source)
        #expect(result.count == 1)
    }
}

extension Lint.Rule.`uint8 ascii extension Tests`.`Edge Case` {
    @Test
    func `extension ASCII Code is NOT flagged`() {
        let source = """
            extension ASCII.Code {
                public static let lf: ASCII.Code = 0x0A
            }
            """
        let result = Lint.Rule.`uint8 ascii extension Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `extension UInt8 with non-ascii members is NOT flagged`() {
        let source = """
            extension UInt8 {
                public static var max: UInt8 { 0xFF }
            }
            """
        let result = Lint.Rule.`uint8 ascii extension Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `extension Byte dot ASCII is NOT flagged`() {
        let source = """
            extension Byte.ASCII {}
            """
        let result = Lint.Rule.`uint8 ascii extension Tests`.findings(in: source)
        #expect(result.isEmpty)
    }
}

extension Lint.Rule.`uint8 ascii extension Tests`.Integration {
    @Test
    func `module-qualified Swift dot UInt8 dot ASCII is flagged`() {
        let source = """
            extension Swift.UInt8.ASCII {}
            """
        let result = Lint.Rule.`uint8 ascii extension Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `large file without UInt8 ascii extensions yields no findings`() {
        let source = String(repeating: "extension Foo: Sendable {}\n", count: 200)
        let result = Lint.Rule.`uint8 ascii extension Tests`.findings(in: source)
        #expect(result.isEmpty)
    }
}
