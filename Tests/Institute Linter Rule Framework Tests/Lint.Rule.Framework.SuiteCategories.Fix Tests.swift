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
import Linter_Rule_Testing
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Institute_Linter_Rule_Framework

extension Lint.Rule {
    @Suite
    struct `suite categories fix Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct `Round Trip` {}
        @Suite struct `Not Fixable` {}
    }
}

extension Lint.Rule.`suite categories fix Tests` {
    static func fixed(_ source: String, file: String = "test.swift") -> String? {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`suite categories`.rewritten(parsed)
    }

    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`suite categories`.observe(parsed, .warning).findings
    }

    /// The self-round-trip property: flagged before, rewritten, parses, and
    /// silent afterwards.
    static func roundTrips(
        _ source: String,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        #expect(
            !findings(in: source).isEmpty,
            "fixture must fire before it can round-trip",
            sourceLocation: sourceLocation
        )
        guard let output = fixed(source) else {
            Issue.record("expected a rewrite", sourceLocation: sourceLocation)
            return
        }
        #expect(
            !Parser.parse(source: output).hasError,
            "rewrite must parse: \(output)",
            sourceLocation: sourceLocation
        )
        #expect(
            findings(in: output).isEmpty,
            "rewrite must re-lint clean: \(output)",
            sourceLocation: sourceLocation
        )
    }

    /// Asserts the rule fires but the fix declines to rewrite — the finding
    /// stands for a person.
    static func declines(
        _ source: String,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        #expect(!findings(in: source).isEmpty, sourceLocation: sourceLocation)
        #expect(fixed(source) == nil, sourceLocation: sourceLocation)
    }

    /// The number of lines (after trimming leading/trailing spaces and tabs)
    /// equal to `needle`, avoiding a dependency on Foundation's
    /// `components(separatedBy:)` / `range(of:)`.
    static func occurrenceCount(of needle: String, in haystack: String) -> Int {
        haystack.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in line.drop { $0 == " " || $0 == "\t" }.reversed() }
            .map { reversed in Swift::String(reversed.drop { $0 == " " || $0 == "\t" }.reversed()) }
            .filter { $0 == needle }
            .count
    }
}

extension Lint.Rule.`suite categories fix Tests`.`Round Trip` {
    @Test
    func `all three categories missing are all appended`() {
        // No direct `@Test` member and no other members at all — the plain
        // case, distinct from the `@Test`-member refusal fixture below.
        let source = """
            @Suite
            struct `Foo Tests` {
            }
            """
        Lint.Rule.`suite categories fix Tests`.roundTrips(source)
        let output = Lint.Rule.`suite categories fix Tests`.fixed(source)
        #expect(output?.contains("@Suite struct Unit {}") == true)
        #expect(output?.contains("@Suite struct `Edge Case` {}") == true)
        #expect(output?.contains("@Suite struct Integration {}") == true)
    }

    @Test
    func `only the one missing category is appended`() {
        let source = """
            @Suite
            struct `Foo Tests` {
                @Suite struct Unit {}
                @Suite struct `Edge Case` {}
            }
            """
        Lint.Rule.`suite categories fix Tests`.roundTrips(source)
        let output = Lint.Rule.`suite categories fix Tests`.fixed(source)
        #expect(output?.contains("@Suite struct Integration {}") == true)
        // The two already-declared categories are untouched, not duplicated:
        // exactly one occurrence of the Unit declaration in the output.
        let count = output.map {
            Lint.Rule.`suite categories fix Tests`.occurrenceCount(
                of: "@Suite struct Unit {}",
                in: $0
            )
        }
        #expect(count == 1)
    }

    @Test
    func `an extra Performance sub-suite is preserved alongside the appended category`() {
        let source = """
            @Suite
            struct `Foo Tests` {
                @Suite struct Unit {}
                @Suite struct `Edge Case` {}
                @Suite(.serialized) struct Performance {}
            }
            """
        Lint.Rule.`suite categories fix Tests`.roundTrips(source)
        let output = Lint.Rule.`suite categories fix Tests`.fixed(source)
        #expect(output?.contains("@Suite struct Integration {}") == true)
        #expect(output?.contains("@Suite(.serialized) struct Performance {}") == true)
    }

    @Test
    func `the house suite idiom - extension-declared suite - is fixed in place`() {
        let source = """
            extension Lint.Rule {
                @Suite
                struct `Foo Tests` {
                    @Suite struct Unit {}
                }
            }
            """
        Lint.Rule.`suite categories fix Tests`.roundTrips(source)
        let output = Lint.Rule.`suite categories fix Tests`.fixed(source)
        #expect(output?.contains("@Suite struct `Edge Case` {}") == true)
        #expect(output?.contains("@Suite struct Integration {}") == true)
    }

    @Test
    func `the qualified @Testing_Suite spelling is fixed on the same terms as the bare spelling`() {
        let source = """
            @Testing.Suite
            struct `Foo Tests` {
                @Suite struct Unit {}
            }
            """
        Lint.Rule.`suite categories fix Tests`.roundTrips(source)
        let output = Lint.Rule.`suite categories fix Tests`.fixed(source)
        #expect(output?.contains("@Suite struct `Edge Case` {}") == true)
        #expect(output?.contains("@Suite struct Integration {}") == true)
    }
}

extension Lint.Rule.`suite categories fix Tests`.`Not Fixable` {
    @Test
    func `an already-compliant suite is not rewritten`() {
        let source = """
            @Suite
            struct `Foo Tests` {
                @Suite struct Unit {}
                @Suite struct `Edge Case` {}
                @Suite struct Integration {}
            }
            """
        #expect(Lint.Rule.`suite categories fix Tests`.findings(in: source).isEmpty)
        #expect(Lint.Rule.`suite categories fix Tests`.fixed(source) == nil)
    }

    @Test
    func `an if-guarded member anywhere in the suite refuses - #if collision is possible`() {
        // [#47] the detector does not splice `#if` when counting declared
        // categories, so a category satisfying the missing set may already
        // exist inside the conditional this fix cannot see. Refuse outright
        // rather than risk a redeclaration in whichever arm is active.
        Lint.Rule.`suite categories fix Tests`.declines(
            """
            @Suite
            struct `Foo Tests` {
                @Suite struct Unit {}
                #if os(Linux)
                @Suite struct `Edge Case` {}
                #endif
            }
            """
        )
    }

    @Test
    func `an if-guarded member unrelated to the missing categories still refuses`() {
        // The refusal is unconditional on ANY `#if` presence in the member
        // block, not only one that plausibly collides — the fix does not
        // attempt to reason about which arm is active.
        Lint.Rule.`suite categories fix Tests`.declines(
            """
            @Suite
            struct `Foo Tests` {
                @Suite struct Unit {}
                #if os(Linux)
                @Test func platformSpecific() {}
                #endif
            }
            """
        )
    }

    @Test
    func `a colliding non-Suite member of the same name refuses`() {
        // The rule's own predicate counts only `@Suite struct` members, so
        // this enum leaves the rule firing while an unconditional insertion
        // of `@Suite struct Unit {}` would be a redeclaration error.
        Lint.Rule.`suite categories fix Tests`.declines(
            """
            @Suite
            struct `Foo Tests` {
                enum Unit {}
            }
            """
        )
    }

    @Test
    func `a colliding stored property of the same name refuses`() {
        Lint.Rule.`suite categories fix Tests`.declines(
            """
            @Suite
            struct `Foo Tests` {
                var Integration: Int = 0
            }
            """
        )
    }

    @Test
    func `a suite with a direct @Test member refuses`() {
        // Inserting empty categories here would silence the finding while
        // leaving the test uncategorised — manufacturing compliance rather
        // than scaffolding it.
        Lint.Rule.`suite categories fix Tests`.declines(
            """
            @Suite
            struct `Foo Tests` {
                @Test func basic() {}
            }
            """
        )
    }

    @Test
    func `a refused suite does not block an unrelated top-level suite's fix`() {
        // Partial application across the file: the refusal is per-declaration,
        // not whole-file.
        let source = """
            @Suite
            struct Skipped {
                #if os(Linux)
                @Suite struct Unit {}
                #endif
            }

            @Suite
            struct Fixed {
                @Suite struct Unit {}
            }
            """
        #expect(Lint.Rule.`suite categories fix Tests`.findings(in: source).count == 2)
        guard let output = Lint.Rule.`suite categories fix Tests`.fixed(source) else {
            Issue.record("expected a partial rewrite")
            return
        }
        #expect(!Parser.parse(source: output).hasError)
        // `Fixed` gained its missing categories.
        #expect(output.contains("struct Fixed"))
        // `Skipped`'s finding still stands — its `#if` is untouched.
        let remaining = Lint.Rule.`suite categories fix Tests`.findings(in: output)
        #expect(remaining.count == 1)
        if remaining.count == 1 {
            #expect(remaining[0].identifier == "suite categories")
        }
    }
}
