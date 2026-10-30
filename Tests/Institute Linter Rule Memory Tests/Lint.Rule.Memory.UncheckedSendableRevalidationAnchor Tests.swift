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
    struct `unchecked sendable revalidation anchor Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`unchecked sendable revalidation anchor Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "Sources/X/Test.swift"
    )
        -> [Diagnostic.Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`unchecked sendable revalidation anchor`.observe(parsed, .warning).findings
    }
}

// MARK: - Unit (positive — rule fires)

extension Lint.Rule.`unchecked sendable revalidation anchor Tests`.Unit {
    @Test
    func `compiler-limitation context with no anchor is flagged`() {
        // Category D citation triggers the in-scope gate. No WHEN TO
        // REMOVE / TRACKING markers — must fire.
        let source = """
            // WHY: Category D — structural Sendable workaround.
            // (missing WHEN TO REMOVE and TRACKING)
            extension Container: @unchecked Sendable {}
            """
        let findings = Lint.Rule.`unchecked sendable revalidation anchor Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "unchecked sendable revalidation anchor")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `compiler-limitation context with anchor missing TRACKING is flagged`() {
        let source = """
            // WHY: Compiler can't prove conditional Sendable for raw-pointer storage.
            // WHEN TO REMOVE: When compiler gains structural Sendable inference.
            // (missing TRACKING)
            extension Container.Variant: @unchecked Sendable where Element: Sendable {}
            """
        let findings = Lint.Rule.`unchecked sendable revalidation anchor Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `WORKAROUND header without three markers is flagged`() {
        let source = """
            // WORKAROUND: @unchecked Sendable on type-erased clock storage.
            public struct AnyClock: @unchecked Sendable {
                private let _erased: () -> Int
            }
            """
        let findings = Lint.Rule.`unchecked sendable revalidation anchor Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `until Swift X-Y context missing TRACKING is flagged`() {
        let source = """
            // WHY: Atomic<T> can't conform to Sendable when T: ~Copyable.
            // WHEN TO REMOVE: until Swift 6.5 lands compiler fix.
            public final class Holder: @unchecked Sendable {
                private var atomic: UnsafeMutablePointer<Int>?
            }
            """
        let findings = Lint.Rule.`unchecked sendable revalidation anchor Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `category D struct with no remove or tracking is flagged`() {
        let source = """
            // WHY: Category D — structural Sendable workaround. UnsafeMutablePointer
            // WHY: blocks structural inference.
            public struct Buffer: @unchecked Sendable {
                private let storage: UnsafeMutablePointer<UInt8>
            }
            """
        let findings = Lint.Rule.`unchecked sendable revalidation anchor Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// MARK: - Edge Case (negative — rule does NOT fire)

extension Lint.Rule.`unchecked sendable revalidation anchor Tests`.`Edge Case` {
    @Test
    func `naked unchecked Sendable with no leading comment is not flagged`() {
        // No comment block at all — no compiler-limitation indicator —
        // out of scope for this rule. Other rules (e.g.
        // `unchecked sendable categorization`) may police naked
        // conformances along different axes.
        let source = """
            extension Container: @unchecked Sendable where Element: Sendable {}
            """
        let findings = Lint.Rule.`unchecked sendable revalidation anchor Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `complete anchor with all three markers is not flagged`() {
        let source = """
            // WHY: Category D — structural Sendable workaround (SP-2).
            // WHEN TO REMOVE: When compiler gains structural Sendable inference through @_rawLayout types.
            // TRACKING: unsafe-audit-findings.md Category D SP-2.
            public struct Storage: @unchecked Sendable {
                private let _raw: UnsafeMutableRawPointer
            }
            """
        let findings = Lint.Rule.`unchecked sendable revalidation anchor Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `semantic-responsibility justification is out of scope`() {
        // No compiler-limitation indicator in the comment block — the
        // justification is "I take responsibility", which is a
        // different axis. The revalidation-anchor rule is silent.
        let source = """
            // I take semantic responsibility: callers must externally synchronize access.
            public struct ManualSync: @unchecked Sendable {}
            """
        let findings = Lint.Rule.`unchecked sendable revalidation anchor Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `prose mentioning unchecked Sendable without indicator keywords is not flagged`() {
        // Comment text mentions `@unchecked Sendable` only as prose;
        // no compiler / limitation / WORKAROUND / Category-X / until
        // Swift / Sendable workaround keyword is present. Out of scope.
        let source = """
            /// This type uses an unchecked conformance for performance reasons.
            extension Coordinator: @unchecked Sendable {}
            """
        let findings = Lint.Rule.`unchecked sendable revalidation anchor Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unchecked Codable (not Sendable) is not flagged`() {
        let source = """
            public struct Container: @unchecked Codable {}
            """
        let findings = Lint.Rule.`unchecked sendable revalidation anchor Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `plain Sendable without unchecked is not flagged`() {
        let source = """
            public struct ValueType: Sendable {}
            """
        let findings = Lint.Rule.`unchecked sendable revalidation anchor Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `multi-line WHY-prefix anchor with all three markers is not flagged`() {
        // Institute convention permits multi-line `// WHY: …` blocks
        // (every line carries the prefix). The marker check is
        // case-insensitive substring on the concatenated comment text;
        // multi-line continuation passes as long as the three keywords
        // each appear at least once.
        let source = """
            // WHY: Type-erased clock struct. Stored fields are @Sendable closures +
            // WHY: generic D: DurationProtocol & Hashable (without Sendable). No
            // WHY: synchronization, no ~Copyable.
            // WHEN TO REMOVE: When compiler gains structural Sendable inference through
            // WHEN TO REMOVE: @Sendable closure storage and generic parameters.
            // TRACKING: unsafe-audit-findings.md Category D SP-7.
            public struct AnyClock: @unchecked Sendable {}
            """
        let findings = Lint.Rule.`unchecked sendable revalidation anchor Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
