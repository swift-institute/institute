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

@testable import Institute_Linter_Rule_Testing

extension Lint.Rule {
    @Suite
    struct `test display name string Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`test display name string Tests` {
    static func findings(
        in source: String,
        file: String = "Tests/X/Thing Tests.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`test display name string`.observe(parsed, .warning).findings
    }
}

// MARK: - Positive: a display string that could be a raw identifier

extension Lint.Rule.`test display name string Tests`.Unit {
    @Test
    func `Test with a could-be-identifier display string is flagged`() {
        let source = """
            @Test("init creates empty buffer")
            func x() {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.count == 1)
        #expect(findings.first?.message == testingDisplayNameStringMessage)
    }

    @Test
    func `Suite with a could-be-identifier display string is flagged`() {
        let source = """
            @Suite("Parsing behaviour")
            struct Parsing {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Suite display string alongside a retained trait is flagged`() {
        // The trait is not the finding — the string is. The canonical fix keeps
        // `.serialized` and drops only the display name.
        let source = """
            @Suite("Performance", .serialized)
            struct Performance {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `qualified @Testing_Test with a display string is flagged`() {
        let source = """
            @Testing.Test("round trips")
            func x() {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `enum, class and actor suites with display strings are each flagged`() {
        let source = """
            @Suite("first") enum A {}
            @Suite("second") final class B {}
            @Suite("third") actor C {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.count == 3)
    }
}

// MARK: - Positive: the duplicate-name compile-error shape

extension Lint.Rule.`test display name string Tests`.Unit {
    @Test
    func `Test display string duplicating its own name is the compile-error shape`() {
        let source = """
            @Test("init creates empty buffer")
            func `init creates empty buffer`() {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.count == 1)
        #expect(findings.first?.message == testingDisplayNameDuplicateMessage)
    }

    @Test
    func `Suite display string duplicating its own name is the compile-error shape`() {
        let source = """
            @Suite("Domain Standard Tests", .serialized)
            struct `Domain Standard Tests` {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.count == 1)
        #expect(findings.first?.message == testingDisplayNameDuplicateMessage)
    }
}

// MARK: - Near-miss: string plus a DIFFERENT backticked name still fires

extension Lint.Rule.`test display name string Tests`.Unit {
    @Test
    func `display string with a different backticked name still fires under the general shape`() {
        // Not the compile-error shape — the compiler accepts it — but the string
        // is still avoidable naming the compiler cannot check, so shape (a)
        // fires with the general message, not the duplicate one.
        let source = """
            @Test("init creates empty buffer")
            func `construction from UInt`() {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.count == 1)
        #expect(findings.first?.message == testingDisplayNameStringMessage)
    }
}

// MARK: - Negative

extension Lint.Rule.`test display name string Tests`.Unit {
    @Test
    func `backticked name with no display string is permitted`() {
        let source = """
            @Test
            func `init creates empty buffer`() {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `attribute carrying only traits is permitted`() {
        let source = """
            @Suite(.serialized)
            struct `Performance` {}

            @Test(.tags(.fast))
            func `comparison`() {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `string literal in a non-testing attribute is not flagged`() {
        let source = """
            @available(*, deprecated, message: "use the other one")
            func helper() {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `labelled string argument is not a display name`() {
        // `arguments:` is parameterised-test data, not naming.
        let source = """
            @Test(arguments: ["a", "b"])
            func `parses each input`(input: String) {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

// MARK: - Edge / exemption: strings that cannot be raw identifiers

extension Lint.Rule.`test display name string Tests`.Unit {
    @Test
    func `display string containing a backtick is exempt`() {
        let source = """
            @Test("the `Test` attribute")
            func x() {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `display string containing an escape is exempt`() {
        let source = #"""
            @Test("line one\nline two")
            func x() {}
            """#
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `interpolated display string is exempt`() {
        let source = #"""
            @Test("case \(index) of many")
            func x() {}
            """#
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `empty and all-space display strings are exempt`() {
        let source = """
            @Test("")
            func x() {}

            @Test("   ")
            func y() {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `all-operator-character display string is exempt`() {
        let source = """
            @Test("<=>")
            func x() {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `display string mixing operator characters with letters still fires`() {
        // Near-miss on the operator-character exemption: `a <= b` is a lawful
        // raw identifier, so the exemption must not swallow it.
        let source = """
            @Test("a <= b")
            func x() {}
            """
        let findings = Lint.Rule.`test display name string Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// MARK: - Self-firing

extension Lint.Rule.`test display name string Tests`.Unit {
    @Test
    func `this suite's own declaration shape produces no findings`() {
        // Self-firing control: the shape this very file uses — a backticked
        // raw-identifier suite name with a bare `@Suite` — must stay clean, and
        // the same shape with a display string added must fire. A rule that
        // cannot separate the two is not known to work.
        let clean = """
            extension Lint.Rule {
              @Suite
              struct `test display name string Tests` {
                @Suite struct Unit {}
              }
            }
            """
        #expect(Lint.Rule.`test display name string Tests`.findings(in: clean).isEmpty)

        let dirty = """
            extension Lint.Rule {
              @Suite("test display name string Tests")
              struct `test display name string Tests` {
                @Suite struct Unit {}
              }
            }
            """
        #expect(Lint.Rule.`test display name string Tests`.findings(in: dirty).count == 1)
    }
}
