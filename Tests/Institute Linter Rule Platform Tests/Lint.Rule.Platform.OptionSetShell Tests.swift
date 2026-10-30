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

@testable import Institute_Linter_Rule_Platform

extension Lint.Rule {
    @Suite
    struct `optionset shell pattern Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`optionset shell pattern Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`optionset shell pattern`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`optionset shell pattern Tests`.Unit {
    @Test
    func `OptionSet with static let Self rawValue in body is flagged`() {
        let source = """
            struct Options: OptionSet {
                let rawValue: Int32
                init(rawValue: Int32) { self.rawValue = rawValue }
                public static let create = Self(rawValue: O_CREAT)
            }
            """
        let findings = Lint.Rule.`optionset shell pattern Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "optionset shell pattern")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `multiple platform constants in body each flagged`() {
        let source = """
            struct Options: OptionSet {
                let rawValue: Int32
                init(rawValue: Int32) { self.rawValue = rawValue }
                public static let create = Self(rawValue: O_CREAT)
                public static let truncate = Self(rawValue: O_TRUNC)
                public static let exclusive = Self(rawValue: O_EXCL)
            }
            """
        let findings = Lint.Rule.`optionset shell pattern Tests`.findings(in: source)
        #expect(findings.count == 3)
    }

    @Test
    func `Swift dot OptionSet conformance is recognized`() {
        let source = """
            struct Options: Swift.OptionSet {
                let rawValue: Int32
                init(rawValue: Int32) { self.rawValue = rawValue }
                public static let bit = Self(rawValue: 1)
            }
            """
        let findings = Lint.Rule.`optionset shell pattern Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`optionset shell pattern Tests`.`Edge Case` {
    @Test
    func `clean shell with only rawValue and init is NOT flagged`() {
        let source = """
            struct Options: OptionSet, Sendable {
                let rawValue: Int32
                init(rawValue: Int32) { self.rawValue = rawValue }
            }
            """
        let findings = Lint.Rule.`optionset shell pattern Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `static constants in extension are NOT flagged`() {
        let source = """
            struct Options: OptionSet {
                let rawValue: Int32
                init(rawValue: Int32) { self.rawValue = rawValue }
            }
            extension Options {
                public static let create = Self(rawValue: O_CREAT)
                public static let truncate = Self(rawValue: O_TRUNC)
            }
            """
        let findings = Lint.Rule.`optionset shell pattern Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct not conforming to OptionSet is NOT flagged`() {
        let source = """
            struct Holder {
                let rawValue: Int32
                public static let foo = Self(rawValue: 0)
            }
            """
        let findings = Lint.Rule.`optionset shell pattern Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `static decl with the type's own name spelling is flagged too`() {
        // #21 defect 11: `<TypeName>(rawValue:)` is one of the three
        // recognized spellings (alongside `Self(rawValue:)` and
        // `.init(rawValue:)`), not a narrower "Self-only" scope. This
        // replaces the prior assertion here, which pinned the pre-fix
        // narrow behavior.
        let source = """
            struct Options: OptionSet {
                let rawValue: Int32
                init(rawValue: Int32) { self.rawValue = rawValue }
                public static let none = Options(rawValue: 0)
            }
            """
        let findings = Lint.Rule.`optionset shell pattern Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `static decl with an unrelated type's initializer is NOT flagged`() {
        let source = """
            struct Options: OptionSet {
                let rawValue: Int32
                init(rawValue: Int32) { self.rawValue = rawValue }
                public static let none = Other(rawValue: 0)
            }
            """
        let findings = Lint.Rule.`optionset shell pattern Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // MARK: - #21 defect 11: the three recognized spellings

    @Test
    func `dot init rawValue spelling is flagged`() {
        let source = """
            struct Options: OptionSet {
                let rawValue: Int32
                init(rawValue: Int32) { self.rawValue = rawValue }
                public static let none = .init(rawValue: 0)
            }
            """
        let findings = Lint.Rule.`optionset shell pattern Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Self dot init rawValue spelling is flagged`() {
        let source = """
            struct Options: OptionSet {
                let rawValue: Int32
                init(rawValue: Int32) { self.rawValue = rawValue }
                public static let none = Self.init(rawValue: 0)
            }
            """
        let findings = Lint.Rule.`optionset shell pattern Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `static var (not let) with Self rawValue is flagged too`() {
        let source = """
            struct Options: OptionSet {
                let rawValue: Int32
                init(rawValue: Int32) { self.rawValue = rawValue }
                public static var custom: Self = Self(rawValue: 0)
            }
            """
        // `var` form, but same `Self(rawValue:)` shape — flagged.
        let findings = Lint.Rule.`optionset shell pattern Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // MARK: - #21 defect 5: member-position `#if` was invisible

    @Test
    func `platform constant guarded by member-position if os is flagged`() {
        let source = """
            struct Options: OptionSet {
                let rawValue: Int32
                init(rawValue: Int32) { self.rawValue = rawValue }
                #if os(Linux)
                static let create = Self(rawValue: 1)
                #endif
            }
            """
        let findings = Lint.Rule.`optionset shell pattern Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
