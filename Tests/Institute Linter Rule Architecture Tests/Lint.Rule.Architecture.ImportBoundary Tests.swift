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

@testable import Institute_Linter_Rule_Architecture

extension Lint.Rule {
    @Suite
    struct `architecture import boundary Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`architecture import boundary Tests` {
    static func findings(
        in source: String,
        file: String = "Sources/Model Core/Model.swift"
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`architecture import boundary`.observe(parsed, .warning).findings
    }

    @Test
    func `@_exported import in an ordinary source file is flagged`() {
        let findings = Self.findings(in: "@_exported import Binary")
        #expect(findings.count == 1)
    }

    @Test
    func `@_exported public import combined form is flagged`() {
        // Attribute AND access modifier on one line — the shape a regex loses.
        let findings = Self.findings(in: "@_exported public import Binary")
        #expect(findings.count == 1)
    }

    @Test
    func `a plain import is not flagged`() {
        let findings = Self.findings(in: "public import Binary")
        #expect(findings.isEmpty)
    }

    @Test
    func `the umbrella exports file is exempt`() {
        // Both-direction fixture for the [RULE-EXEMPT-12] umbrella carve-out.
        let findings = Self.findings(
            in: "@_exported public import Binary",
            file: "Sources/Model Core/exports.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a file merely ENDING in exports_swift is not the umbrella`() {
        // Near-miss: exact whole-filename match only.
        for path in [
            "Sources/Model Core/ReExports.swift",
            "Sources/Model Core/Model.exports.swift",
        ] {
            let findings = Self.findings(
                in: "@_exported import Binary",
                file: path
            )
            #expect(findings.count == 1, "expected a finding for \(path)")
        }
    }

    @Test
    func `a directory named exports_swift does not exempt its contents`() {
        // The umbrella is a FILE; a directory segment of the same spelling is
        // not it.
        let findings = Self.findings(
            in: "@_exported import Binary",
            file: "Sources/Model Core/exports.swift/Model.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `test sources are exempt`() {
        // Both-direction fixture for the non-main-target carve-out.
        let findings = Self.findings(
            in: "@_exported import Binary",
            file: "Tests/Model Core Tests/Support.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a space-separated MAIN target directory is not accidentally exempted`() {
        let findings = Self.findings(
            in: "@_exported import Binary",
            file: "Sources/Products Live/Client.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `an attribute that merely resembles _exported does not fire`() {
        // Near-miss on the attribute name itself.
        let findings = Self.findings(in: "@_implementationOnly import Binary")
        #expect(findings.isEmpty)
    }

    @Test
    func `every scattered re-export in one file is reported`() {
        let source = """
            @_exported public import Binary
            import Time
            @_exported public import Time
            """
        let findings = Self.findings(in: source)
        #expect(findings.count == 2)
    }
}
