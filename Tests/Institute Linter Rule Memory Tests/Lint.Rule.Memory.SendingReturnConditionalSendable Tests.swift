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

@testable import Institute_Linter_Rule_Memory

extension Lint.Rule {
    @Suite
    struct `sending return conditional sendable state Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct Negative {}
    }
}

extension Lint.Rule.`sending return conditional sendable state Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "Sources/X/Test.swift"
    )
        -> [Diagnostic.Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`sending return conditional sendable state`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`sending return conditional sendable state Tests`.Unit {
    @Test
    func `sending Base optional return on unchecked-Sendable-conditional-on-Base type is flagged`() {
        // The reproduction shape from swift-property#7: `State`
        // is `@unchecked Sendable` conditional on `Base: Sendable`, and
        // `borrow()` returns `sending Base?` instead of the required plain
        // `Base?`.
        let source = """
            public final class State<Base> {
                public func borrow() -> sending Base? { fatalError() }
            }
            extension State: @unchecked Sendable where Base: Sendable {}
            """
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(
            in: source
        )
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "sending return conditional sendable state")
        }
    }

    @Test
    func `sending Base (non-optional) return is flagged`() {
        let source = """
            public final class State<Base> {
                public func borrow() -> sending Base { fatalError() }
            }
            extension State: @unchecked Sendable where Base: Sendable {}
            """
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(
            in: source
        )
        #expect(findings.count == 1)
    }

    @Test
    func `package-scoped member with sending Base return is flagged`() {
        let source = """
            public final class State<Base> {
                package func consume() -> sending Base? { fatalError() }
            }
            extension State: @unchecked Sendable where Base: Sendable {}
            """
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(
            in: source
        )
        #expect(findings.count == 1)
    }

    @Test
    func `member of a public extension with no modifier of its own is flagged`() {
        // A member of a `public extension` is public API without carrying
        // the keyword itself.
        let source = """
            public final class State<Base> {}
            public extension State {
                func borrow() -> sending Base? { fatalError() }
            }
            extension State: @unchecked Sendable where Base: Sendable {}
            """
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(
            in: source
        )
        #expect(findings.count == 1)
    }

    @Test
    func `gate declared before the member is still resolved`() {
        // The gate extension can appear anywhere in the file relative to
        // the member — resolution happens after the whole file is walked.
        let source = """
            extension State: @unchecked Sendable where Base: Sendable {}
            public final class State<Base> {
                public func borrow() -> sending Base? { fatalError() }
            }
            """
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(
            in: source
        )
        #expect(findings.count == 1)
    }

    @Test
    func `sending array of Base return is flagged`() {
        let source = """
            public final class State<Base> {
                public func drain() -> sending [Base] { fatalError() }
            }
            extension State: @unchecked Sendable where Base: Sendable {}
            """
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(
            in: source
        )
        #expect(findings.count == 1)
    }

    @Test
    func `subscript with sending Base return is flagged`() {
        let source = """
            public final class State<Base> {
                public subscript(index: Int) -> sending Base { fatalError() }
            }
            extension State: @unchecked Sendable where Base: Sendable {}
            """
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(
            in: source
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`sending return conditional sendable state Tests`.`Edge Case` {
    @Test
    func `sending return mentioning an unrelated type is NOT flagged`() {
        // The `sending` return here doesn't mention the gated parameter
        // `Base` at all.
        let source = """
            public final class State<Base> {
                public func other() -> sending Int { fatalError() }
            }
            extension State: @unchecked Sendable where Base: Sendable {}
            """
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(
            in: source
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `two distinct types are tracked independently`() {
        let source = """
            public final class Good<Base> {
                public func borrow() -> Base? { fatalError() }
            }
            extension Good: @unchecked Sendable where Base: Sendable {}

            public final class Bad<Base> {
                public func borrow() -> sending Base? { fatalError() }
            }
            extension Bad: @unchecked Sendable where Base: Sendable {}
            """
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(
            in: source
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`sending return conditional sendable state Tests`.Negative {
    @Test
    func `plain Base optional return (no sending) is NOT flagged`() {
        let source = """
            public final class State<Base> {
                public func borrow() -> Base? { fatalError() }
            }
            extension State: @unchecked Sendable where Base: Sendable {}
            """
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(
            in: source
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `sending Base return with no conditional-Sendable gate is NOT flagged`() {
        let source = """
            public final class State<Base> {
                public func borrow() -> sending Base? { fatalError() }
            }
            """
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(
            in: source
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `plain (non-unchecked) conditional Sendable conformance is NOT flagged`() {
        // A real (compiler-checked) conditional Sendable conformance is
        // verified per-member by the compiler already — @unchecked is the
        // load-bearing signal that separates "checked automatically" from
        // "a human asserted this."
        let source = """
            public final class State<Base> {
                public func borrow() -> sending Base? { fatalError() }
            }
            extension State: Sendable where Base: Sendable {}
            """
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(
            in: source
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `internal member is NOT flagged`() {
        let source = """
            public final class State<Base> {
                func borrow() -> sending Base? { fatalError() }
            }
            extension State: @unchecked Sendable where Base: Sendable {}
            """
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(
            in: source
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `unconditional unchecked Sendable (no where clause) is NOT flagged`() {
        // No generic parameter is gated, so nothing to cross-reference —
        // this is `Storage`'s own shape in the adjudication (unconditional
        // `@unchecked Sendable`, single internal use), which is out of
        // this rule's scope by construction.
        let source = """
            public struct Storage<Base> {
                public func borrow() -> sending Base? { fatalError() }
            }
            extension Storage: @unchecked Sendable {}
            """
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(
            in: source
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `empty file produces no findings`() {
        let findings = Lint.Rule.`sending return conditional sendable state Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }
}
