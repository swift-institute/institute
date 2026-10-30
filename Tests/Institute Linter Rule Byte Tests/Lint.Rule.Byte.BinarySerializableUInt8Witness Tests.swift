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
    struct `binary serializable uint8 witness Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`binary serializable uint8 witness Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`binary serializable uint8 witness`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`binary serializable uint8 witness Tests`.Unit {
    @Test
    func `serialize where Buffer Element equals UInt8 is flagged`() {
        let source = """
            extension RFC_791.TypeOfService: Binary.Serializable {
                public static func serialize<Buffer: RangeReplaceableCollection>(
                    _ tos: Self, into buffer: inout Buffer
                ) where Buffer.Element == UInt8 {}
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `parse where Source Element equals UInt8 is flagged`() {
        let source = """
            extension RFC_791.Flags: Binary.Parseable {
                public static func parse<Source: Collection>(
                    _ source: Source
                ) -> Self where Source.Element == UInt8 { fatalError() }
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    // Arc G Phase 7 addendum (2026-05-20): default-impl-extension shape.
    // Default impls on `Binary.Serializable` / `Binary.Parseable` are witness
    // implementations too — for any conformer without an override. The rule's
    // gate covers BOTH the conformer-extension shape (above) AND this shape.

    @Test
    func `default-impl on Binary Serializable where Buffer Element equals UInt8 is flagged`() {
        let source = """
            extension Binary.Serializable {
                public func serialize<Buffer: RangeReplaceableCollection>(
                    into buffer: inout Buffer
                ) where Buffer.Element == UInt8 {}
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `default-impl on Binary Parseable where Source Element equals UInt8 is flagged`() {
        let source = """
            extension Binary.Parseable {
                public static func parse<Source: Collection>(
                    _ source: Source
                ) -> Self where Source.Element == UInt8 { fatalError() }
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    // swiftlint:disable:next function_name_whitespace
    func
        `conditional default-impl on Binary Serializable where Buffer Element equals UInt8 is flagged`()
    {
        let source = """
            extension Binary.Serializable where Self: RawRepresentable {
                public func serialize<Buffer: RangeReplaceableCollection>(
                    into buffer: inout Buffer
                ) where Buffer.Element == UInt8 {}
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `initializer witness where Source Element equals UInt8 is flagged`() {
        // `Binary.Parseable` is idiomatically satisfied by an initializer,
        // not only a static `parse` function — `"init"` is listed in
        // `byteWitnessFunctionNames` but was unreachable because the visitor
        // only overrode `FunctionDeclSyntax`.
        let source = """
            extension Foo: Binary.Parseable {
                public init<Source: Collection>(parsing s: Source) where Source.Element == UInt8 {}
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `sibling-family Binary ASCII Serializable witness is flagged`() {
        // `Binary.ASCII.Serializable` reduces to base leaf `ASCII`, not the
        // family host `Binary` — matching must resolve to the outermost
        // root identifier, not just the immediate parent segment.
        let source = """
            extension Foo: Binary.ASCII.Serializable {
                public static func serialize<Buffer: RangeReplaceableCollection>(
                    _ x: Self, into buffer: inout Buffer
                ) where Buffer.Element == UInt8 {}
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.count == 1)
    }
}

extension Lint.Rule.`binary serializable uint8 witness Tests`.`Edge Case` {
    @Test
    func `initializer witness where Source Element equals Byte is NOT flagged`() {
        let source = """
            extension Foo: Binary.Parseable {
                public init<Source: Collection>(parsing s: Source) where Source.Element == Byte {}
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `disfavored UInt8 initializer witness is NOT flagged`() {
        let source = """
            extension Foo: Binary.Parseable {
                @_disfavoredOverload
                public init<Source: Collection>(parsing s: Source) where Source.Element == UInt8 {}
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.isEmpty)
    }
}

extension Lint.Rule.`binary serializable uint8 witness Tests`.`Edge Case` {
    @Test
    func `serialize where Buffer Element equals Byte is NOT flagged`() {
        let source = """
            extension RFC_791.TypeOfService: Binary.Serializable {
                public static func serialize<Buffer: RangeReplaceableCollection>(
                    _ tos: Self, into buffer: inout Buffer
                ) where Buffer.Element == Byte {}
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `disfavored UInt8 forwarder in Binary Serializable extension is NOT flagged`() {
        let source = """
            extension RFC_791.TypeOfService: Binary.Serializable {
                @_disfavoredOverload
                public static func serialize<Buffer: RangeReplaceableCollection>(
                    _ tos: Self, into buffer: inout Buffer
                ) where Buffer.Element == UInt8 {}
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `serialize outside Binary Serializable extension is NOT flagged`() {
        let source = """
            extension Array where Element == UInt8 {
                public static func serialize(_ x: Self) where Buffer.Element == UInt8 {}
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    // Arc G Phase 7 addendum (2026-05-20): default-impl-extension shape — negative cases.

    @Test
    func `default-impl on Binary Serializable with Byte where-clause is NOT flagged`() {
        let source = """
            extension Binary.Serializable {
                public func serialize<Buffer: RangeReplaceableCollection>(
                    into buffer: inout Buffer
                ) where Buffer.Element == Byte {}
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `disfavored UInt8 default-impl forwarder on Binary Serializable is NOT flagged`() {
        let source = """
            extension Binary.Serializable {
                @_disfavoredOverload
                public func serialize<Buffer: RangeReplaceableCollection>(
                    into buffer: inout Buffer
                ) where Buffer.Element == UInt8 {}
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.isEmpty)
    }

    @Test
    func `default-impl on Binary Parseable with Byte where-clause is NOT flagged`() {
        let source = """
            extension Binary.Parseable {
                public static func parse<Source: Collection>(
                    _ source: Source
                ) -> Self where Source.Element == Byte { fatalError() }
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.isEmpty)
    }
}

extension Lint.Rule.`binary serializable uint8 witness Tests`.Integration {
    @Test
    func `module-qualified Binary Serializable conformance is recognized`() {
        let source = """
            extension Foo: Binary.Serializable {
                public static func serialize<Buffer: RangeReplaceableCollection>(
                    _ x: Self, into buffer: inout Buffer
                ) where Buffer.Element == UInt8 {}
            }
            """
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.count == 1)
    }

    @Test
    func `non-Binary-Serializable extensions yield no findings`() {
        let source = String(repeating: "extension Foo: Sendable {}\n", count: 200)
        let result = Lint.Rule.`binary serializable uint8 witness Tests`.findings(in: source)
        #expect(result.isEmpty)
    }
}
