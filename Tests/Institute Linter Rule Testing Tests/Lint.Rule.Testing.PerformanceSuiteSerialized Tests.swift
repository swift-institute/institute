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
    struct `performance suite serialized Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`performance suite serialized Tests` {
    static func findings(
        in source: String,
        file: String = "Sources/X/Test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`performance suite serialized`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`performance suite serialized Tests`.Unit {
    @Test
    func `Performance suite without serialized is flagged`() {
        let source = """
            @Suite struct Performance {}
            """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Performance suite with serialized is permitted`() {
        let source = """
            @Suite(.serialized) struct Performance {}
            """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `trait argument merely containing the substring serialized does not count`() {
        // #24 nit: replaces a `.contains(".serialized")` textual scan with
        // a structural check — a differently-named member ending in the
        // same substring must NOT satisfy the requirement.
        let source = """
            @Suite(.notSerialized) struct Performance {}
            """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Performance struct without Suite attr and without Test functions is not flagged`() {
        let source = """
            struct Performance {}
            """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // #24 defect 2: a type with no explicit `@Suite` is still an
    // implicit suite under Swift Testing if it declares a `@Test`
    // function — the shape that previously lacked `.serialized`
    // invisibly, since the rule required an explicit `@Suite` to look.

    @Test
    func `Performance struct with a Test function but no Suite is flagged`() {
        let source = """
            struct Performance {
                @Test func f() {}
            }
            """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Performance enum with a Test function but no Suite is flagged`() {
        let source = """
            enum Performance {
                @Test static func f() {}
            }
            """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Performance class with a Test function but no Suite is flagged`() {
        let source = """
            class Performance {
                @Test func f() {}
            }
            """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Performance actor with a Test function but no Suite is flagged`() {
        let source = """
            actor Performance {
                @Test func f() {}
            }
            """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Suite on non-Performance type is not flagged`() {
        let source = """
            @Suite struct Unit {}
            """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Performance suite with multiple traits including serialized is permitted`() {
        let source = """
            @Suite(.tags(.benchmark), .serialized) struct Performance {}
            """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
