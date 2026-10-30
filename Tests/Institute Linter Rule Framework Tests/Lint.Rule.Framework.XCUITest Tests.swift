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
import Testing

@testable import Institute_Linter_Rule_Framework

extension Lint.Rule {
    @Suite
    struct `xcuitest reference Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`xcuitest reference Tests` {
    static func findings(in source: String, file: String) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`xcuitest reference`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`xcuitest reference Tests`.Unit {
    @Test
    func `XCUITest references in a UI test target are warnings`() {
        let source = """
            let application = XCUIApplication()
            let element: XCUIElement
            let query: XCUIElementQuery
            """
        let findings = Lint.Rule.`xcuitest reference Tests`.findings(
            in: source,
            file: "Tests/Example UI Tests/Launch Tests.swift"
        )
        #expect(findings.count == 3)
        #expect(findings.allSatisfy { $0.identifier == "xcuitest reference" })
        #expect(findings.allSatisfy { $0.severity == .warning })
        #expect(findings.allSatisfy { $0.message == frameworkXCUITestMessage })
    }

    @Test
    func `XCTest import in a UI test target is a warning`() {
        let findings = Lint.Rule.`xcuitest reference Tests`.findings(
            in: "import XCTest",
            file: "Tests/Example UI Tests/Launch Tests.swift"
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`xcuitest reference Tests`.`Edge Case` {
    @Test
    func `lawful Swift Testing suite is clean`() {
        let source = """
            import Testing

            @Suite struct Launch {
                @Test func starts() {}
            }
            """
        let findings = Lint.Rule.`xcuitest reference Tests`.findings(
            in: source,
            file: "Tests/Example UI Tests/Launch Tests.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `XCUITest use inside a Swift Testing test still fires`() {
        let source = """
            import Testing

            @Test func starts() {
                _ = XCUIApplication()
            }
            """
        let findings = Lint.Rule.`xcuitest reference Tests`.findings(
            in: source,
            file: "Tests/Example UI Tests/Launch Tests.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `same identifiers outside a UI test target are clean`() {
        let findings = Lint.Rule.`xcuitest reference Tests`.findings(
            in: "let application = XCUIApplication()",
            file: "Tests/Example Tests/Launch Tests.swift"
        )
        #expect(findings.isEmpty)
    }
}
