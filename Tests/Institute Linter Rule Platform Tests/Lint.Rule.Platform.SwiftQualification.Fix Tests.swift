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

@testable import Institute_Linter_Rule_Platform

extension Lint.Rule {
    @Suite
    struct `swift protocol qualification fix Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct `Round Trip` {}
        @Suite struct `Not Fixable` {}
    }
}

extension Lint.Rule.`swift protocol qualification fix Tests` {
    static func fixed(_ source: String, file: String = "test.swift") -> String? {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`swift protocol qualification`.rewritten(parsed)
    }

    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`swift protocol qualification`.observe(parsed, .warning).findings
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
}

extension Lint.Rule.`swift protocol qualification fix Tests`.`Round Trip` {
    @Test
    func `a generic parameter constraint is qualified`() {
        let source = """
            func op<E: Error>(_ error: E) {}
            """
        Lint.Rule.`swift protocol qualification fix Tests`.roundTrips(source)
        let output = Lint.Rule.`swift protocol qualification fix Tests`.fixed(source)
        #expect(output?.contains("<E: Swift.Error>") == true)
    }

    @Test
    func `an opaque parameter constraint is qualified with its generic argument`() {
        let source = """
            func op(_ bytes: some Sequence<UInt8>) {}
            """
        Lint.Rule.`swift protocol qualification fix Tests`.roundTrips(source)
        #expect(
            Lint.Rule.`swift protocol qualification fix Tests`
                .fixed(source)?.contains("some Swift.Sequence<UInt8>") == true
        )
    }

    @Test
    func `an inherited type is qualified`() {
        let source = """
            struct Bag: Collection {}
            """
        Lint.Rule.`swift protocol qualification fix Tests`.roundTrips(source)
        let output = Lint.Rule.`swift protocol qualification fix Tests`.fixed(source)
        #expect(output?.contains(": Swift.Collection") == true)
    }

    @Test
    func `a where-clause conformance requirement is qualified`() {
        let source = """
            func op<T>(_ value: T) where T: Sequence {}
            """
        Lint.Rule.`swift protocol qualification fix Tests`.roundTrips(source)
    }

    @Test
    func `every leaf of a composition is qualified`() {
        let source = """
            func op<T: Sequence & Collection>(_ value: T) {}
            """
        Lint.Rule.`swift protocol qualification fix Tests`.roundTrips(source)
        let output = Lint.Rule.`swift protocol qualification fix Tests`.fixed(source)
        #expect(output?.contains("Swift.Sequence & Swift.Collection") == true)
    }

    @Test
    func `surrounding text is preserved verbatim`() {
        let source = """
            /// Doc comment.
            public func op<E: Error>(_ error: E) -> Swift.Bool {
                return true
            }
            """
        let output = Lint.Rule.`swift protocol qualification fix Tests`.fixed(source)
        #expect(output?.contains("/// Doc comment.\n") == true)
        #expect(output?.contains("    return true\n") == true)
    }
}

extension Lint.Rule.`swift protocol qualification fix Tests`.`Not Fixable` {
    @Test
    func `an already-qualified reference is not rewritten`() {
        let source = """
            func op<E: Swift.Error>(_ error: E) {}
            """
        #expect(Lint.Rule.`swift protocol qualification fix Tests`.findings(in: source).isEmpty)
        #expect(Lint.Rule.`swift protocol qualification fix Tests`.fixed(source) == nil)
    }

    @Test
    func `an extension on a stdlib type keeps the exemption`() {
        // [RULE-EXEMPT-6] (stdlib-shadow): inside `extension Array`, the
        // qualified form does not resolve, so writing it would turn a warning
        // into a compile error. The rule does not fire, and the fix must not
        // fire either — the two must agree on every input.
        let source = """
            extension Array {
                func op<E: Error>(_ error: E) {}
            }
            """
        #expect(Lint.Rule.`swift protocol qualification fix Tests`.findings(in: source).isEmpty)
        #expect(Lint.Rule.`swift protocol qualification fix Tests`.fixed(source) == nil)
    }
}

extension Lint.Rule.`swift protocol qualification fix Tests`.`Not Fixable` {
    /// Asserts the rule still fires but declines to rewrite — the finding
    /// stands for a person, who is the only one who knows which `Error` the
    /// file meant.
    static func declines(
        _ source: String,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        #expect(
            !Lint.Rule.`swift protocol qualification fix Tests`.findings(in: source).isEmpty,
            sourceLocation: sourceLocation
        )
        #expect(
            Lint.Rule.`swift protocol qualification fix Tests`.fixed(source) == nil,
            sourceLocation: sourceLocation
        )
    }

    /// The rewrite here compiles and flips `x is Error` from true to false.
    @Test
    func `a file declaring its own Error protocol is not rewritten`() {
        Self.declines(
            """
            protocol Error {
                var code: Int { get }
            }
            struct Boom: Error { var code: Int { 7 } }
            func handle(_ e: any Error) -> Int { e.code }
            """
        )
    }

    /// The rewrite here silently drops the `Sendable` bound.
    @Test
    func `a file aliasing Error to a constrained existential is not rewritten`() {
        Self.declines(
            """
            typealias Error = Swift.Error & Sendable
            struct E2: Error {}
            func log(_ e: any Error) { _ = e }
            """
        )
    }

    /// The alias is nested, and the reference is inside the namespace that
    /// declares it. Refusing the whole file is the file-local rule.
    @Test
    func `a nested Error typealias suppresses the fix file-wide`() {
        Self.declines(
            """
            enum Namespace {
                typealias Error = CustomStringConvertible
            }
            extension Namespace {
                static func describe(_ e: any Error) -> String { e.description }
            }
            """
        )
    }

    @Test
    func `a file declaring its own Sequence type is not rewritten`() {
        Self.declines(
            """
            struct Sequence {}
            func op<T: Sequence>(_ value: T) {}
            """
        )
    }

    @Test
    func `an associated type named Collection suppresses the fix`() {
        Self.declines(
            """
            protocol Store {
                associatedtype Collection
            }
            func op<T: Collection>(_ value: T) {}
            """
        )
    }

    @Test
    func `a generic parameter named Error suppresses the fix`() {
        Self.declines(
            """
            struct Box<Error> {
                let value: Error
            }
            func op(_ e: any Error) {}
            """
        )
    }

    /// Only the shadowed name is withheld. A file that declares `Error` and
    /// also references `Sequence` still gets its `Sequence` qualified.
    @Test
    func `an unshadowed name is still qualified in a shadowing file`() {
        let source = """
            protocol Error {}
            func op<T: Sequence>(_ value: T) {}
            func handle(_ e: any Error) {}
            """
        let output = Lint.Rule.`swift protocol qualification fix Tests`.fixed(source)
        #expect(output?.contains("<T: Swift.Sequence>") == true)
        #expect(output?.contains("any Error") == true)
        #expect(output?.contains("Swift.Error") == false)
    }
}
