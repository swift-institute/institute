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
    struct `stdlib forwarder outside sli Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`stdlib forwarder outside sli Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`stdlib forwarder outside sli`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`stdlib forwarder outside sli Tests`.Unit {
    @Test
    func `disfavored init taking a qualified Swift Array of UInt8 in primary module is flagged`() {
        // The house convention module-qualifies stdlib collections
        // (`Swift.Array<UInt8>`); the type-mention detector must descend
        // into a `MemberTypeSyntax`'s generic-argument clause, not just an
        // `IdentifierTypeSyntax`'s.
        let source = """
            extension Array where Element == UInt8 {
                @_disfavoredOverload
                public init(bytes: Swift.Array<UInt8>) {
                    self = []
                }
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.count == 1)
    }

    @Test
    func `disfavored Array UInt8 init in primary module is flagged`() {
        let source = """
            extension Array where Element == UInt8 {
                @_disfavoredOverload
                public init<S: Binary.Serializable>(_ s: S) {
                    self = []
                }
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.count == 1)
        if result.count == 1 {
            #expect(result[0].identifier == "stdlib forwarder outside sli")
        }
    }

    @Test
    func `disfavored ContiguousArray UInt8 init in primary module is flagged`() {
        let source = """
            extension ContiguousArray where Element == UInt8 {
                @_disfavoredOverload
                public init<S: Binary.Serializable>(_ s: S) {
                    self = []
                }
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.count == 1)
    }

    @Test
    func `disfavored Swift Array explicit qualifier UInt8 init in primary module is flagged`() {
        let source = """
            extension Swift.Array where Element == UInt8 {
                @_disfavoredOverload
                public init<S: Binary.Serializable>(_ s: S) {
                    self = []
                }
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.count == 1)
    }

    @Test
    func `disfavored RangeReplaceableCollection UInt8 append in primary module is flagged`() {
        let source = """
            extension RangeReplaceableCollection where Element == UInt8 {
                @_disfavoredOverload
                public mutating func append<S: Binary.Serializable>(_ s: S) {}
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.count == 1)
    }
}

extension Lint.Rule.`stdlib forwarder outside sli Tests`.`Edge Case` {
    @Test
    func `disfavored Array UInt8 in Standard Library Integration module is NOT flagged`() {
        let source = """
            extension Array where Element == UInt8 {
                @_disfavoredOverload
                public init<S: Binary.Serializable>(_ s: S) {
                    self = []
                }
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo Standard Library Integration/Bar.swift"
        )
        #expect(result.isEmpty)
    }

    @Test
    func
        `disfavored Array UInt8 in SLI module is NOT flagged with an earlier Sources path segment`()
    {
        // Regression guard: the host-target anchor must be the LAST `Sources`
        // path component. A checkout root that happens to contain an earlier
        // `Sources` segment (e.g. `/Users/dev/Sources/checkout/Sources/Foo
        // Standard Library Integration/Bar.swift`) must not have that earlier
        // segment steal the anchor and misresolve the host target name.
        let source = """
            extension Array where Element == UInt8 {
                @_disfavoredOverload
                public init<S: Binary.Serializable>(_ s: S) {
                    self = []
                }
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/Users/dev/Sources/checkout/Sources/Foo Standard Library Integration/Bar.swift"
        )
        #expect(result.isEmpty)
    }

    @Test
    func `Array UInt8 init without disfavoredOverload is NOT flagged`() {
        let source = """
            extension Array where Element == UInt8 {
                public init<S: Binary.Serializable>(_ s: S) {
                    self = []
                }
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.isEmpty)
    }

    @Test
    func `disfavored Array Byte function without UInt8 surface is NOT flagged`() {
        let source = """
            extension Array where Element == Byte {
                @_disfavoredOverload
                public func bar(_ value: Byte) {}
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.isEmpty)
    }

    @Test
    func `extension on institute type Byte Input with disfavored UInt8 init is NOT flagged`() {
        // [API-BYTE-007] scope: only extensions on STDLIB types belong in SLI.
        // Extensions on institute types (ArraySlice<Byte> here) that take UInt8 as
        // a stdlib-bridge convenience legitimately live in the primary module.
        let source = """
            extension ArraySlice<Byte> {
                @_disfavoredOverload
                public init<Bytes: Swift.Collection>(_ bytes: Bytes) where Bytes.Element == UInt8 {
                    self.init(Swift.Array(bytes))
                }
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.isEmpty)
    }

    @Test
    func `extension on institute type Foo with disfavored UInt8 ArraySlice init is NOT flagged`() {
        let source = """
            extension Foo {
                @_disfavoredOverload
                public init(_ bytes: ArraySlice<UInt8>) {}
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.isEmpty)
    }

    @Test
    func `extension on RFC namespaced type with disfavored UInt8 init is NOT flagged`() {
        let source = """
            extension RFC_4122.UUID {
                @_disfavoredOverload
                public init(_ data: [UInt8]) {}
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.isEmpty)
    }

    @Test
    func `disfavored Array UInt8 init with Optional in primary module is flagged`() {
        let source = """
            extension Array where Element == UInt8? {
                @_disfavoredOverload
                public init<S: Binary.Serializable>(_ s: S) {
                    self = []
                }
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.count == 1)
    }

    @Test
    func `top-level disfavored UInt8 function is NOT flagged`() {
        // Not inside an extension at all — rule scope is extensions only.
        let source = """
            @_disfavoredOverload
            public func bar(_ value: UInt8) {}
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.isEmpty)
    }
}

extension Lint.Rule.`stdlib forwarder outside sli Tests`.Integration {
    @Test
    func `multiple disfavored UInt8 forwarders in stdlib type extension are all flagged`() {
        let source = """
            extension Array where Element == UInt8 {
                @_disfavoredOverload
                public init<S: Binary.Serializable>(_ s: S) { self = [] }
                @_disfavoredOverload
                public func bytes() -> [UInt8] { [] }
                public func unrelated() {}
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.count == 2)
    }

    @Test
    func `mixed primary and SLI fixtures separate independently`() {
        // Each `findings(...)` call is independent — this test confirms the
        // module-detection logic doesn't leak between calls.
        let primarySource = """
            extension Array where Element == UInt8 {
                @_disfavoredOverload
                public init<S: Binary.Serializable>(_ s: S) { self = [] }
            }
            """
        let primary = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: primarySource,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        let sli = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: primarySource,
            file: "/pkg/Sources/Foo Standard Library Integration/Bar.swift"
        )
        #expect(primary.count == 1)
        #expect(sli.isEmpty)
    }

    @Test
    func `mixed institute and stdlib extensions in same file fire selectively`() {
        // [API-BYTE-007] scope discrimination: only the stdlib-type extension fires.
        let source = """
            extension ArraySlice<Byte> {
                @_disfavoredOverload
                public init(_ bytes: ArraySlice<UInt8>) {}
            }
            extension Array where Element == UInt8 {
                @_disfavoredOverload
                public init<S: Binary.Serializable>(_ s: S) { self = [] }
            }
            """
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.count == 1)
    }

    @Test
    func `large file with no disfavored UInt8 surfaces yields no findings`() {
        let source = String(repeating: "extension Foo { func bar() {} }\n", count: 200)
        let result = Lint.Rule.`stdlib forwarder outside sli Tests`.findings(
            in: source,
            file: "/pkg/Sources/Foo/Bar.swift"
        )
        #expect(result.isEmpty)
    }
}
