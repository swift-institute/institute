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
    struct `configuration before content Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`configuration before content Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`configuration before content`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`configuration before content Tests`.Unit {
    @Test
    func `Options between two domain parameters is flagged`() {
        let source = """
            func perform(on target: Target, options: Options, mode: Mode) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "configuration before content")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `Configuration in the middle is flagged`() {
        let source = """
            func op(a: A, configuration: Configuration, b: B) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Context in the middle with trailing closure is flagged`() {
        let source = """
            func op(a: A, context: Context, b: B, body: () -> Void) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple configuration parameters in the middle each flagged`() {
        let source = """
            func op(a: A, options: Options, b: B, context: Context, c: C) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`configuration before content Tests`.`Edge Case` {
    @Test
    func `Options at last non-closure position is NOT flagged`() {
        let source = """
            func perform(on target: Target, mode: Mode, options: Options = []) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Options last before trailing closure is NOT flagged`() {
        let source = """
            func perform(on target: Target, mode: Mode, options: Options = [], body: () -> Void) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Configuration at first position is NOT flagged`() {
        let source = """
            init(_ configuration: Configuration = .default, mode: Mode, target: Target) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `single configuration parameter is NOT flagged`() {
        let source = """
            init(_ configuration: Configuration = .default) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `two parameters with config first is NOT flagged`() {
        let source = """
            init(options: Options = [], extra: Int) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `two parameters with config last is NOT flagged`() {
        let source = """
            init(extra: Int, options: Options = []) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `qualified Foo dot Options counts as configuration type`() {
        let source = """
            func op(a: A, options: Foo.Options, b: B) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `unrelated middle parameter (not config) is NOT flagged`() {
        let source = """
            func op(a: A, mode: Mode, b: B) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // #24 defect 4: the predicate is a suffix test, not exact equality —
    // `RenderOptions`, `ParseConfiguration`, `RequestContext` all match.

    @Test
    func `RenderOptions suffix in middle position is flagged`() {
        let source = """
            func op(a: A, settings: RenderOptions, b: B) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `ParseConfiguration suffix in middle position is flagged`() {
        let source = """
            func op(a: A, settings: ParseConfiguration, b: B) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `RequestContext suffix in middle position is flagged`() {
        let source = """
            func op(a: A, settings: RequestContext, b: B) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `suffix mid-name (not ending in a configuration suffix) is NOT flagged`() {
        let source = """
            func op(a: A, settings: OptionsHolder, b: B) {}
            """
        let findings = Lint.Rule.`configuration before content Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
