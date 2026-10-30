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

@testable import Institute_Linter_Rule_Closure

extension Lint.Rule {
    @Suite
    struct `unlabeled lifecycle closure Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`unlabeled lifecycle closure Tests` {
    static func findings(
        in source: String,
        file: String = "Sources/X/Test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`unlabeled lifecycle closure`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`unlabeled lifecycle closure Tests`.Unit {
    @Test
    func `single unlabelled closure is permitted`() {
        let source = """
            func f(_ body: () -> Void) {}
            """
        let findings = Lint.Rule.`unlabeled lifecycle closure Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `two closures both unlabelled flags second`() {
        let source = """
            func f(_ body: () -> Void, _ completion: () -> Void) {}
            """
        let findings = Lint.Rule.`unlabeled lifecycle closure Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `two closures with second labelled is permitted`() {
        let source = """
            func f(_ body: () -> Void, completion: () -> Void) {}
            """
        let findings = Lint.Rule.`unlabeled lifecycle closure Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `three closures with second-and-third unlabelled flags both`() {
        let source = """
            func f(_ body: () -> Void, _ completion: () -> Void, _ teardown: () -> Void) {}
            """
        let findings = Lint.Rule.`unlabeled lifecycle closure Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    // swiftlint:disable:next function_name_whitespace
    func
        `non-closure parameter between closures (also a violation but for a different rule) is not flagged here`()
    {
        let source = """
            func f(_ body: () -> Void, count: Int, completion: () -> Void) {}
            """
        // This file's rule only checks unlabelled secondary closures.
        // The misordering is the closure_param_position rule's job.
        let findings = Lint.Rule.`unlabeled lifecycle closure Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `init enforces multi-closure labelling`() {
        let source = """
            struct S {
                init(_ body: () -> Void, _ completion: () -> Void) {}
            }
            """
        let findings = Lint.Rule.`unlabeled lifecycle closure Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`unlabeled lifecycle closure Tests`.`Edge Case` {
    @Test
    func `escaping second closure unlabelled is flagged`() {
        let source = """
            func f(_ body: () -> Void, _ completion: @escaping () -> Void) {}
            """
        let findings = Lint.Rule.`unlabeled lifecycle closure Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `optional second closure unlabelled is flagged`() {
        let source = """
            func f(_ body: () -> Void, _ completion: (() -> Void)?) {}
            """
        let findings = Lint.Rule.`unlabeled lifecycle closure Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `function with non-closure params only is not flagged`() {
        let source = "func f(a: Int, b: String) {}"
        let findings = Lint.Rule.`unlabeled lifecycle closure Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
