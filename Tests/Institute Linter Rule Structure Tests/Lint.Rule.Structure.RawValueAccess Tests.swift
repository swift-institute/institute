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

@testable import Institute_Linter_Rule_Structure

extension Lint.Rule {
    @Suite
    struct `raw value access Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`raw value access Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`raw value access`.observe(parsed, .warning).findings
    }

    /// Findings against a run whose brand pre-pass stamped `types`.
    static func findings(
        in source: String,
        types: Set<String>
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, types: types)
        return Lint.Rule.`raw value access`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`raw value access Tests`.`Edge Case` {
    @Test
    func `brand-owner run self-suppresses raw value access (§A)`() {
        // The run's own sources declare `Cardinal` (∈ numeric vocabulary), so
        // same-package `.rawValue` boundary access is legitimate — zero findings.
        let findings = Lint.Rule.`raw value access Tests`.findings(
            in: "func op(tag: MyTag) { let raw = tag.rawValue; use(raw) }",
            types: ["Cardinal"]
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `consumer run still fires raw value access (§A)`() {
        // The run declares no brand from the vocabulary — cross-package firing
        // is preserved by construction.
        let findings = Lint.Rule.`raw value access Tests`.findings(
            in: "func op(tag: MyTag) { let raw = tag.rawValue; use(raw) }",
            types: ["SomeConsumerType"]
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`raw value access Tests`.Unit {
    @Test
    func `rawValue access inside function body is flagged`() {
        let source = """
            func op(tag: MyTag) {
                let raw = tag.rawValue
                use(raw)
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "raw value access")
        }
    }

    @Test
    func `ordinary position vocabulary is not treated as raw value access`() {
        let source = """
            func op(index: MyIndex) {
                let p = index.position
                use(p)
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`raw value access Tests`.`Edge Case` {
    @Test
    func `rawValue at top-level type scope is NOT flagged`() {
        // `bodyDepth == 0`: the access sits directly in a stored-property
        // initializer at type scope, outside any function-like body, so the
        // gate exempts it regardless of accessor name.
        let source = """
            struct Foo {
                static let max = MyTag.rawValue
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `rawValue access inside a shorthand computed getter is flagged`() {
        // A short-form getter (`{ tag.rawValue }`, no explicit `get { }`)
        // parses as `AccessorBlockSyntax.getter` — there is no
        // `AccessorDeclSyntax` node. The rule must not depend on which of the
        // two equivalent spellings the author used.
        let source = """
            struct Wrapper {
                var stripped: Int32 { tag.rawValue }
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `rawValue access inside a shorthand subscript getter is flagged`() {
        let source = """
            struct Wrapper {
                subscript(index: Int) -> Int32 { tags[index].rawValue }
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `unrelated member access is NOT flagged`() {
        let source = """
            func op(tag: MyTag) {
                let n = tag.name
                use(n)
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Receiver-pattern disambiguation — Swift.enum.rawValue (i.e.,
    // `Type.case.rawValue`) is RawRepresentable territory, not the
    // Tagged-newtype consumer access this rule targets. Per the
    // foundation-up dogfeed (A2), these MUST NOT fire.
    // See Research/2026-05-12-foundation-up-dogfeed-triage.md §A2.

    @Test
    func `Type case rawValue is NOT flagged - enum case access disambiguation`() {
        let source = """
            func op() {
                let s = Visibility.public.rawValue
                use(s)
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `qualified Type case rawValue is NOT flagged`() {
        let source = """
            func op() {
                let s = Lint.Visibility.public.rawValue
                use(s)
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `instance rawValue is still flagged - Tagged consumer access`() {
        // Positive case: the rule's target is Tagged consumer access.
        let source = """
            func op(tag: MyTag) {
                let r = tag.rawValue
                use(r)
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `self tag rawValue is still flagged`() {
        let source = """
            struct Holder {
                var tag: MyTag
                func op() {
                    let r = self.tag.rawValue
                    use(r)
                }
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// #16 Option C ledger, Entry II.1 (DECISION 2026-07-23): the
// initializer-boundary reserve. The rule's message reserves the flagged
// accessors for "extension initializers (the brand-newtype's own
// boundary)"; the implementation now honors that reserve.
extension Lint.Rule.`raw value access Tests`.`Edge Case` {
    @Test
    func `self rawValue assignment inside declaring init is NOT flagged`() {
        // The swift-iso-9945 `ISO 9945.Kernel.Process.ID` shape.
        let source = """
            public struct ID: RawRepresentable {
                public let rawValue: Int32
                public init(rawValue: Int32) {
                    self.rawValue = rawValue
                }
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `brand rawValue consumption inside adapter extension init is NOT flagged`() {
        // The swift-sockets-ip-address `Kernel.Socket.Address.IPv4+IP` shape
        // (#16 Entry III.f): the extension initializer IS the conversion
        // boundary.
        let source = """
            extension Kernel.Socket.Address.IPv4 {
                public init(ip: IPv4.Address, port: UInt16 = 0) {
                    let address: UInt32 = ip.rawValue
                    self.init(address: address.bigEndian, port: port)
                }
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `rawValue inside a closure nested in an init is still flagged`() {
        // Only the directly-enclosing initializer context is the boundary;
        // a closure inside it is ordinary consumer code.
        let source = """
            struct Holder {
                init(tags: [MyTag]) {
                    self.values = tags.map { tag in tag.rawValue }
                }
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `rawValue in ordinary function body is still flagged after II-1`() {
        // Positive control: the consumer-call-site signal is preserved.
        let source = """
            func send(tag: MyTag) {
                transmit(tag.rawValue)
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // #28 nit 2: `isDirectlyInsideInitializer`'s `Deinitializer` /
    // `Subscript` walk-stopper guards were untested. Pinning both
    // fixtures before touching the guards, per the ruling.

    @Test
    func `rawValue access inside a deinit body is flagged`() {
        let source = """
            final class Owner {
                let x: MyTag
                deinit {
                    log(x.rawValue)
                }
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `rawValue access inside an explicit subscript body is flagged`() {
        let source = """
            struct Table {
                subscript(i: Int) -> Int {
                    get { tags[i].rawValue }
                }
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// #38: the same-package implementation-site reserve. The message reserves
// these accessors for the brand's own initializers AND same-package
// implementations; this is the second clause, for the one shape with a
// stable syntactic property — the receiver is the enclosing type's own
// instance.
extension Lint.Rule.`raw value access Tests`.`Edge Case` {
    @Test
    func `Self-typed operator parameters are NOT flagged`() {
        // The brand's own arithmetic — the high-volume same-package shape.
        let source = """
            extension Cardinal {
                public static func + (lhs: Self, rhs: Self) -> Self {
                    Cardinal(lhs.rawValue + rhs.rawValue)
                }
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `a parameter written as the enclosing type name is NOT flagged`() {
        let source = """
            extension Cardinal {
                public func combined(with other: Cardinal) -> Int {
                    other.rawValue
                }
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `self rawValue in the brand's own serializer is NOT flagged`() {
        let source = """
            extension Cardinal {
                public var description: String {
                    String(self.rawValue)
                }
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `a borrowing Self parameter is NOT flagged`() {
        let source = """
            struct Cardinal {
                func compare(to other: borrowing Self) -> Bool {
                    other.rawValue == 0
                }
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Near-miss: a parameter of a FOREIGN brand inside the same extension is
    // cross-package consumer access and still fires.
    @Test
    func `a foreign brand parameter in the brand's own extension is still flagged`() {
        let source = """
            extension Cardinal {
                public func scaled(by factor: Ordinal) -> Int {
                    factor.rawValue
                }
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Near-miss: a Self-typed parameter captured inside a nested closure is
    // not the directly enclosing function's parameter.
    @Test
    func `a Self parameter accessed from a nested closure is still flagged`() {
        let source = """
            extension Cardinal {
                public func each(_ other: Self) {
                    run { other.rawValue }
                }
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Near-miss control: a top-level consumer function keeps firing.
    @Test
    func `a Self-named parameter outside any type is still flagged`() {
        let source = """
            func op(tag: Cardinal) -> Int {
                tag.rawValue
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`raw value access Tests`.`Edge Case` {
    @Test
    func `rawValue remains governed beside ordinary position vocabulary`() {
        let source = """
            struct Cursor {
                var position: Int
            }
            func op(tag: MyTag) {
                use(tag.rawValue)
            }
            """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
