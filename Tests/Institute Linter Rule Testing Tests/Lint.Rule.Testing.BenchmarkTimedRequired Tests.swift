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
    struct `benchmark timed required Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`benchmark timed required Tests` {
    static func findings(
        in source: String,
        file: String = "Sources/X/Test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`benchmark timed required`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`benchmark timed required Tests`.Unit {
    @Test
    func `Test inside Performance suite without timed is flagged`() {
        let source = """
            @Suite(.serialized) struct Performance {
                @Test
                func `runs fast`() {}
            }
            """
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Test inside Performance suite with timed is permitted`() {
        let source = """
            @Suite(.serialized) struct Performance {
                @Test(.timed())
                func `runs fast`() {}
            }
            """
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `qualified @Testing_Test inside Performance suite without timed is flagged`() {
        let source = """
            @Suite(.serialized) struct Performance {
                @Testing.Test
                func `runs fast`() {}
            }
            """
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Test outside Performance suite is not flagged`() {
        let source = """
            @Suite struct Unit {
                @Test
                func `something`() {}
            }
            """
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Test inside Performance extension without timed is flagged`() {
        let source = """
            extension Foo.Test.Performance {
                @Test
                func `runs fast`() {}
            }
            """
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Test with timed threshold is permitted`() {
        let source = """
            @Suite(.serialized) struct Performance {
                @Test(.timed(threshold: .milliseconds(50)))
                func `meets budget`() {}
            }
            """
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `trait argument merely containing the substring timed does not count`() {
        // #24 nit: replaces a `.contains(".timed")` textual scan with a
        // structural check — a differently-named call ending in the same
        // substring must NOT satisfy the requirement.
        let source = """
            @Suite(.serialized) struct Performance {
                @Test(.untimed())
                func `meets budget`() {}
            }
            """
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// MARK: - The [BENCH-003] executable-variant citation carve (Round M ζ pilot 3)

extension Lint.Rule.`benchmark timed required Tests` {
    @Suite struct `Variant Exemption` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`benchmark timed required Tests`.`Variant Exemption` {
    @Test
    func `suite-level variant citation exempts every contained test`() {
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(
            in: """
                // Load-scale gates; measurement lives in Benchmarks/ ([BENCH-003] executable variant).
                struct Performance {
                    @Test func growthCurve() {}
                    @Test func `Validation Flat`() {}
                }
                """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `function-level variant citation exempts that test only`() {
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(
            in: """
                struct Performance {
                    // [BENCH-003] executable variant: measured in Benchmarks/.
                    @Test func growthCurve() {}
                    @Test func `Unmeasured`() {}
                }
                """
        )
        #expect(findings.count == 1)
    }

    @Test
    func `a later suite without the citation still fires (depth stays balanced)`() {
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(
            in: """
                // [BENCH-003] variant.
                struct Performance {
                    @Test func exempt() {}
                }
                struct Performance {
                    @Test func fires() {}
                }
                """
        )
        #expect(findings.count == 1)
    }
}
