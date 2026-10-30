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
    struct `architecture foundation type Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`architecture foundation type Tests` {
    static func findings(
        in source: String,
        file: String = "Sources/Model Core/Model.swift"
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`architecture foundation type`.observe(parsed, .warning).findings
    }

    @Test
    func `a module-qualified Foundation type is flagged without any import`() {
        // The transitive re-export blind spot: no import statement in sight.
        let findings = Self.findings(in: "public var payload: Foundation.Data")
        #expect(findings.count == 1)
    }

    @Test
    func `every family member's qualification is flagged`() {
        for module in [
            "Foundation", "FoundationEssentials", "FoundationNetworking", "FoundationXML",
        ] {
            let findings = Self.findings(in: "let value: \(module).Data")
            #expect(findings.count == 1, "expected a finding for \(module).Data")
        }
    }

    @Test
    func `an NS-prefixed class in type position is flagged`() {
        let findings = Self.findings(in: "let lock: NSLock")
        #expect(findings.count == 1)
    }

    @Test
    func `NSObject inheritance is flagged`() {
        let findings = Self.findings(in: "public class Model: NSObject {}")
        #expect(findings.count == 1)
    }

    @Test
    func `an unqualified short Foundation name is deliberately not flagged`() {
        // AST-locally indistinguishable from an institute-owned type of the
        // same spelling; guessing is worse than a bounded claim.
        let findings = Self.findings(in: "let payload: Data")
        #expect(findings.isEmpty)
    }

    @Test
    func `an all-caps NS lookalike does not fire`() {
        // Near-miss control: `NS` + uppercase run with no lowercase is not a
        // Foundation class spelling.
        let findings = Self.findings(in: "let value: NSFW")
        #expect(findings.isEmpty)
    }

    @Test
    func `a nested qualification whose base is not the module does not fire`() {
        // `My.Foundation.X` — the base type is itself a member type, not the
        // Foundation module identifier.
        let findings = Self.findings(in: "let value: My.Foundation.Custom")
        #expect(findings.isEmpty)
    }

    @Test
    func `a Foundation Integration subtarget is exempt`() {
        // Both-direction fixture for the [RULE-EXEMPT-12] carve-out.
        let findings = Self.findings(
            in: "public var payload: Foundation.Data",
            file: "Sources/JSON Foundation Integration/Bridge.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a core target merely NAMED with Foundation is not exempted`() {
        let findings = Self.findings(
            in: "let lock: NSLock",
            file: "Sources/HTML Foundation/Render.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `test sources are exempt`() {
        let findings = Self.findings(
            in: "let lock: NSLock",
            file: "Tests/Model Core Tests/Support.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a package manifest is exempt`() {
        let findings = Self.findings(
            in: "let root: Foundation.URL",
            file: "Package.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a qualified use is reported once, not once per component`() {
        let findings = Self.findings(in: "func f() -> Foundation.URL { fatalError() }")
        #expect(findings.count == 1)
    }
}
