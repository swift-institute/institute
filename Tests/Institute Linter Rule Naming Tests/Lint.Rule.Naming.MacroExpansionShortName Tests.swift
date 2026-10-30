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

@testable import Institute_Linter_Rule_Naming

extension Lint.Rule {
    @Suite
    struct `macro expansion short name Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`macro expansion short name Tests` {
    static func findings(in source: Swift::String) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: "Sources/Value Macros/ValueMacro.swift")
        return Lint.Rule.`macro expansion short name`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`macro expansion short name Tests`.Unit {
    @Test
    func `unqualified extension target is flagged`() {
        let source = """
            struct ValueMacro: ExtensionMacro {
                static func expansion() -> [ExtensionDeclSyntax] {
                    ["extension Value: Swift.Sendable {}"]
                }
            }
            """
        let findings = Lint.Rule.`macro expansion short name Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "macro expansion short name")
            #expect(findings[0].severity == .warning)
            #expect(findings[0].message == namingMacroExpansionShortNameMessage("Value"))
        }
    }
}

extension Lint.Rule.`macro expansion short name Tests`.`Edge Case` {
    @Test
    func `fully qualified extension target and inherited type are lawful`() {
        let source = """
            struct ValueMacro: ExtensionMacro {
                static func expansion() -> [ExtensionDeclSyntax] {
                    ["extension Domain.Value: Swift.Sendable {}"]
                }
            }
            """
        let findings = Lint.Rule.`macro expansion short name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `fully qualified target with unqualified inherited type still fires`() {
        let source = """
            struct ValueMacro: ExtensionMacro {
                static func expansion() -> [ExtensionDeclSyntax] {
                    ["extension Domain.Value: Sendable {}"]
                }
            }
            """
        let findings = Lint.Rule.`macro expansion short name Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].message == namingMacroExpansionShortNameMessage("Sendable"))
        }
    }

    @Test
    func `non macro expansion function is out of scope`() {
        let source = """
            struct Builder {
                static func expansion() -> Swift.String {
                    "extension Value: Swift.Sendable {}"
                }
            }
            """
        let findings = Lint.Rule.`macro expansion short name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
