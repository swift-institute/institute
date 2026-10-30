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
    struct `protocol sentinel under generic front door Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct Negative {}
    }
}

extension Lint.Rule.`protocol sentinel under generic front door Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`protocol sentinel under generic front door`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`protocol sentinel under generic front door Tests`.Unit {
    @Test
    func `backtick Protocol sentinel nested under a generic front-door carrier is flagged`() {
        // The retired swift-set shape: a public generic front
        // door (`Set<Element>`) fronting an underscored carrier (`__Set`),
        // with the Protocol sentinel nested via an extension of the
        // CARRIER, not the alias.
        let source = """
            public typealias Set<Element> = __Set<Element>

            public struct __Set<Element> {}

            extension __Set where Element: Hashable {
                public typealias `Protocol` = __SetProtocol
            }
            """
        let findings = Lint.Rule.`protocol sentinel under generic front door Tests`.findings(
            in: source
        )
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "protocol sentinel under generic front door")
        }
    }

    @Test
    func `bare Protocol sentinel (unescaped) is also flagged`() {
        let source = """
            public typealias Array<Element> = __Array<Element>

            public struct __Array<Element> {}

            extension __Array {
                public typealias Protocol = __ArrayProtocol
            }
            """
        let findings = Lint.Rule.`protocol sentinel under generic front door Tests`.findings(
            in: source
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Protocol sentinel nested as a struct is flagged`() {
        let source = """
            public typealias Tree<Element> = __Tree<Element>

            public struct __Tree<Element> {}

            extension __Tree {
                public struct `Protocol` {}
            }
            """
        let findings = Lint.Rule.`protocol sentinel under generic front door Tests`.findings(
            in: source
        )
        #expect(findings.count == 1)
    }

    @Test
    func `gate declared before the sentinel extension is still resolved`() {
        // The front-door typealias can appear anywhere in the file
        // relative to the extension — resolution happens after the whole
        // file is walked.
        let source = """
            extension __Set {
                public typealias `Protocol` = __SetProtocol
            }

            public typealias Set<Element> = __Set<Element>
            public struct __Set<Element> {}
            """
        let findings = Lint.Rule.`protocol sentinel under generic front door Tests`.findings(
            in: source
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`protocol sentinel under generic front door Tests`.`Edge Case` {
    @Test
    func `Protocol sentinel nested on the front-door alias name itself is NOT flagged`() {
        // No SEPARATE carrier is being extended here — this doesn't
        // reproduce the alias/carrier split the doctrine identifies.
        let source = """
            public typealias Set<Element> = __Set<Element>

            extension Set {
                public typealias `Protocol` = __SetProtocol
            }
            """
        let findings = Lint.Rule.`protocol sentinel under generic front door Tests`.findings(
            in: source
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `non-generic typealias is NOT a front door - not flagged`() {
        let source = """
            public typealias Alias = Underlying

            extension Underlying {
                public typealias `Protocol` = UnderlyingProtocol
            }
            """
        let findings = Lint.Rule.`protocol sentinel under generic front door Tests`.findings(
            in: source
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`protocol sentinel under generic front door Tests`.Negative {
    @Test
    func
        `bare non-generic namespace with directly-nested Protocol is NOT flagged - Store precedent`()
    {
        // Reference non-firing shape: `Store` is a bare, non-generic
        // enum namespace with its own directly-nested `Protocol` member —
        // there is no separate generic front-door typealias pointing at
        // `Store`, so member lookup resolves normally.
        let source = """
            public enum Store {}

            extension Store {
                public typealias `Protocol` = __StoreProtocol
            }
            """
        let findings = Lint.Rule.`protocol sentinel under generic front door Tests`.findings(
            in: source
        )
        #expect(findings.isEmpty)
    }

    @Test
    // swiftlint:disable:next function_name_whitespace
    func
        `generic carrier struct with no nested Protocol sentinel is NOT flagged - Storage precedent`()
    {
        // Reference non-firing shape: `Storage::Storage<Allocation>` is a real
        // generic struct with no nested `Protocol` sentinel at all —
        // Allocation-independent capability surfaces are hoisted to
        // non-generic homes instead, exactly to avoid this failure mode.
        let source = """
            public typealias Storage<Allocation> = __Storage<Allocation>

            public struct __Storage<Allocation> {}

            extension __Storage {
                public struct Contiguous<Element> {}
            }
            """
        let findings = Lint.Rule.`protocol sentinel under generic front door Tests`.findings(
            in: source
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `internal (non-public) generic typealias is NOT a front door`() {
        let source = """
            typealias Carrier<T> = __Carrier<T>

            extension __Carrier {
                public typealias `Protocol` = __CarrierProtocol
            }
            """
        let findings = Lint.Rule.`protocol sentinel under generic front door Tests`.findings(
            in: source
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `unrelated nested member (not Protocol) is NOT flagged`() {
        let source = """
            public typealias Set<Element> = __Set<Element>

            extension __Set {
                public typealias Index = Int
            }
            """
        let findings = Lint.Rule.`protocol sentinel under generic front door Tests`.findings(
            in: source
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `empty file produces no findings`() {
        let findings = Lint.Rule.`protocol sentinel under generic front door Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }
}
