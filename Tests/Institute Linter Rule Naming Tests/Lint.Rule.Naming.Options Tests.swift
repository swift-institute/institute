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

@testable import Institute_Linter_Rule_Naming

extension Lint.Rule {
    @Suite
    struct `property named flags Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`property named flags Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`property named flags`.observe(parsed, .warning).findings
    }
}

// swiftlint:disable options_not_flags
// REASON: this suite's fixture sources deliberately embed .Flags-suffixed OptionSet names as
// string literals under test
// (self-referential fixture shape, rule-exemptions skill); re-enabled at end of file.
extension Lint.Rule.`property named flags Tests`.Unit {
    @Test
    func `OptionSet struct ending in Flags is flagged`() {
        let source = """
            struct OpenFlags: OptionSet {
                let rawValue: Int
            }
            """
        let findings = Lint.Rule.`property named flags Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "property named flags")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `OptionSet struct with Swift dot OptionSet inheritance is flagged`() {
        let source = """
            struct OpenFlags: Swift.OptionSet {
                let rawValue: Int
            }
            """
        let findings = Lint.Rule.`property named flags Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple inheritance with OptionSet is flagged`() {
        let source = """
            struct OpenFlags: OptionSet, Sendable {
                let rawValue: Int
            }
            """
        let findings = Lint.Rule.`property named flags Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple offending types are all flagged`() {
        let source = """
            struct AFlags: OptionSet { let rawValue: Int }
            struct BFlags: OptionSet { let rawValue: Int }
            struct CFlags: OptionSet { let rawValue: Int }
            """
        let findings = Lint.Rule.`property named flags Tests`.findings(in: source)
        #expect(findings.count == 3)
    }

    @Test
    func `nested OptionSet ending in Flags is flagged`() {
        let source = """
            enum File {
                struct OpenFlags: OptionSet {
                    let rawValue: Int
                }
            }
            """
        let findings = Lint.Rule.`property named flags Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`property named flags Tests`.`Edge Case` {
    @Test
    func `OptionSet struct named Options is NOT flagged`() {
        let source = """
            struct OpenOptions: OptionSet {
                let rawValue: Int
            }
            """
        let findings = Lint.Rule.`property named flags Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-OptionSet struct ending in Flags is NOT flagged`() {
        let source = """
            struct DebugFlags {
                var verbose: Bool
            }
            """
        let findings = Lint.Rule.`property named flags Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-OptionSet struct ending in Flags with Sendable is NOT flagged`() {
        let source = """
            struct DebugFlags: Sendable {
                var verbose: Bool
            }
            """
        let findings = Lint.Rule.`property named flags Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `bare struct named Flags IS flagged`() {
        // Bare `Flags` is the exact C-speak this rule targets — it must not be
        // exempt merely because it has no further prefix.
        let source = """
            struct Flags: OptionSet {
                let rawValue: Int
            }
            """
        let findings = Lint.Rule.`property named flags Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `class named XFlags conforming to OptionSet is NOT flagged`() {
        // The rule visits StructDeclSyntax only — a class carrying the same
        // name and conformance shape is out of scope. The fixture must
        // actually declare the conformance the title names, or the branch
        // this test claims to pin (ClassDeclSyntax never visited) is untested.
        let source = """
            class OpenFlags: OptionSet {
                var rawValue: Int = 0
            }
            """
        let findings = Lint.Rule.`property named flags Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
// swiftlint:enable options_not_flags
