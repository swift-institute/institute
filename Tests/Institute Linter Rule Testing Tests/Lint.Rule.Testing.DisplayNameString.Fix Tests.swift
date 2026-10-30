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

@testable import Institute_Linter_Rule_Testing

extension Lint.Rule.`test display name string Tests` {
    static func fixed(_ source: Swift::String) -> Swift::String? {
        let parsed = Lint.Source.parsed(from: source, file: "Tests/X/Thing Tests.swift")
        return Lint.Rule.`test display name string`.rewritten(parsed)
    }

    static func name(ofFirstFunctionIn source: Swift::String) -> Swift::String? {
        let parsed = Parser.parse(source: source)
        for statement in parsed.statements {
            if let function = statement.item.as(FunctionDeclSyntax.self) {
                return function.name.trimmedDescription
            }
        }
        return nil
    }

    static func verify(
        _ source: Swift::String,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) -> Swift::String? {
        #expect(
            !findings(in: source).isEmpty,
            "fixture must fire before it can round-trip",
            sourceLocation: sourceLocation
        )
        guard let output = fixed(source) else {
            Issue.record("expected a binding-preserving rewrite", sourceLocation: sourceLocation)
            return nil
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
        #expect(
            fixed(output) == nil,
            "a clean result must be idempotent",
            sourceLocation: sourceLocation
        )
        return output
    }
}

extension Lint.Rule.`test display name string Tests`.Unit {
    @Test
    func `a duplicate Test display string is removed`() {
        let source = """
            @Test("init creates empty buffer")
            func `init creates empty buffer`() {}
            """
        let output = Lint.Rule.`test display name string Tests`.verify(source)
        #expect(
            output
                == """
                @Test
                func `init creates empty buffer`() {}
                """
        )
    }

    @Test
    func `a duplicate Suite display string keeps its trait`() {
        let source = """
            @Suite("Domain Standard Tests", .serialized)
            struct `Domain Standard Tests` {}
            """
        let output = Lint.Rule.`test display name string Tests`.verify(source)
        #expect(
            output
                == """
                @Suite(.serialized)
                struct `Domain Standard Tests` {}
                """
        )
    }

    @Test
    func `qualified attributes and parameter arguments are retained`() {
        let source = """
            @Testing.Test("round trips", .tags(.fast), arguments: [1, 2])
            func `round trips`(_ value: Int) {}
            """
        let output = Lint.Rule.`test display name string Tests`.verify(source)
        #expect(
            output
                == """
                @Testing.Test(.tags(.fast), arguments: [1, 2])
                func `round trips`(_ value: Int) {}
                """
        )
    }

    @Test
    func `multiline trait trivia is retained`() {
        let source = """
            @Suite(
              "Parsing Tests",
              // Serialization is intentional.
              .serialized
            )
            struct `Parsing Tests` {}
            """
        let output = Lint.Rule.`test display name string Tests`.verify(source)
        #expect(
            output
                == """
                @Suite(
                  // Serialization is intentional.
                  .serialized
                )
                struct `Parsing Tests` {}
                """
        )
    }

    @Test
    func `comments around a singleton display argument are retained`() {
        let source = """
            @Test(
              /* display prefix */ "commented identity" /* display suffix */
            )
            func `commented identity`() {}
            """
        let output = Lint.Rule.`test display name string Tests`.verify(source)
        #expect(output?.contains("/* display prefix */") == true)
        #expect(output?.contains("/* display suffix */") == true)
        #expect(
            Lint.Rule.`test display name string Tests`.name(ofFirstFunctionIn: output ?? "")
                == "`commented identity`"
        )
    }

    @Test
    func `duplicate displays on every supported declaration kind are removed`() {
        let source = """
            @Test("function") func `function`() {}
            @Suite("structure") struct `structure` {}
            @Suite("enumeration") enum `enumeration` {}
            @Suite("class") final class `class` {}
            @Suite("actor") actor `actor` {}
            """
        let output = Lint.Rule.`test display name string Tests`.verify(source)
        #expect(output?.contains("@Test func `function`()") == true)
        #expect(output?.contains("@Suite struct `structure`") == true)
        #expect(output?.contains("@Suite enum `enumeration`") == true)
        #expect(output?.contains("@Suite final class `class`") == true)
        #expect(output?.contains("@Suite actor `actor`") == true)
    }
}

extension Lint.Rule.`test display name string Tests`.Integration {
    @Test
    func `the declaration identity token and references never change`() {
        let source = """
            @Test("semantic identity")
            func `semantic identity`() {
              _ = #function
            }

            let reference = `semantic identity`
            """
        let before = Lint.Rule.`test display name string Tests`.name(ofFirstFunctionIn: source)
        let output = Lint.Rule.`test display name string Tests`.verify(source)
        let after = output.flatMap {
            Lint.Rule.`test display name string Tests`.name(ofFirstFunctionIn: $0)
        }
        #expect(before == "`semantic identity`")
        #expect(after == before)
        #expect(output?.contains("let reference = `semantic identity`") == true)
        #expect(output?.contains("_ = #function") == true)
    }

}

extension Lint.Rule.`test display name string Tests`.`Edge Case` {
    @Test
    func `a different declaration name is routed as rename required and refused`() {
        let source = """
            @Test("init creates empty buffer")
            func `construction from UInt`() {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.count == 1)
        #expect(findings.first?.message == testingDisplayNameStringMessage)
        #expect(findings.first?.message.contains("Rename required; autofix refused") == true)
        #expect(Lint.Rule.`test display name string Tests`.fixed(source) == nil)
    }

    @Test
    func `an equal bare identifier is still rename required`() {
        let source = """
            @Test("example")
            func example() {}
            """
        #expect(Lint.Rule.`test display name string Tests`.findings(in: source).count == 1)
        #expect(Lint.Rule.`test display name string Tests`.fixed(source) == nil)
    }

    @Test
    func `near misses and exempt display strings are never rewritten`() {
        let source = #"""
            @available(*, deprecated, message: "use other")
            func `non testing`() {}

            @Test(arguments: ["a", "b"])
            func `labelled data`(_ value: String) {}

            @Test("case \(index)")
            func `interpolated display`() {}
            """#
        #expect(Lint.Rule.`test display name string Tests`.findings(in: source).isEmpty)
        #expect(Lint.Rule.`test display name string Tests`.fixed(source) == nil)
    }

}

extension Lint.Rule.`test display name string Tests`.Integration {
    @Test
    func `the rule suite's duplicate shape self-round-trips`() {
        let source = """
            extension Lint.Rule {
              @Suite("test display name string Tests")
              struct `test display name string Tests` {
                @Suite struct Unit {}
              }
            }
            """
        let output = Lint.Rule.`test display name string Tests`.verify(source)
        #expect(output?.contains("@Suite\n  struct `test display name string Tests`") == true)
    }
}
