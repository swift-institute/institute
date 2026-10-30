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

@testable import Institute_Linter_Rule_Framework

extension Lint.Rule {
    @Suite
    struct `xctest import Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`xctest import Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`xctest import`.observe(parsed, .warning).findings
    }
}

// swiftlint:disable no_xctest_import
// REASON: this suite's fixture sources deliberately embed 'import XCTest' as
// string literals under test
// (self-referential fixture shape, rule-exemptions skill); re-enabled at end of file.
extension Lint.Rule.`xctest import Tests`.Unit {
    @Test
    func `bare XCTest import is flagged`() {
        let source = "import XCTest"
        let findings = Lint.Rule.`xctest import Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "xctest import")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `XCTest submodule import is flagged`() {
        let source = "import XCTest.XCTestCase"
        let findings = Lint.Rule.`xctest import Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `XCTest alongside other imports flags only XCTest`() {
        let source = """
            import Testing
            import XCTest
            import Foundation
            """
        let findings = Lint.Rule.`xctest import Tests`.findings(in: source)
        // Only XCTest is in scope of this rule; Foundation is handled by [PRIM-FOUND-001].
        #expect(findings.count == 1)
    }

    @Test
    func `public import of XCTest is flagged`() {
        let source = "public import XCTest"
        let findings = Lint.Rule.`xctest import Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `internal import of XCTest is flagged`() {
        let source = "internal import XCTest"
        let findings = Lint.Rule.`xctest import Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`xctest import Tests`.`Edge Case` {
    @Test
    func `Testing framework import is NOT flagged`() {
        let source = """
            import Testing
            """
        let findings = Lint.Rule.`xctest import Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Swift stdlib imports are NOT flagged`() {
        let source = """
            import Swift
            import Synchronization
            """
        let findings = Lint.Rule.`xctest import Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `module with XCTest in name (not the framework) is NOT flagged`() {
        // A hypothetical module named `XCTestHelpers` would import as
        // `XCTestHelpers` — not the XCTest framework itself. Only the
        // first path component is checked for equality with "XCTest".
        let source = "import XCTestHelpers"
        let findings = Lint.Rule.`xctest import Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `SwiftSyntaxMacrosGenericTestSupport is NOT flagged`() {
        // The framework-agnostic macro test support per
        // [SWIFT-TEST-013] does NOT pull XCTest. It must remain
        // importable from Swift Testing macro tests.
        let source = "import SwiftSyntaxMacrosGenericTestSupport"
        let findings = Lint.Rule.`xctest import Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `empty source produces no findings`() {
        let source = ""
        let findings = Lint.Rule.`xctest import Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
// swiftlint:enable no_xctest_import
