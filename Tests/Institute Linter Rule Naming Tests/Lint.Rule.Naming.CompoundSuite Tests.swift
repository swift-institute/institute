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

@testable import Institute_Linter_Rule_Naming

extension Lint.Rule {
    @Suite
    struct `compound suite name Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`compound suite name Tests` {
    static func findings(
        in source: String,
        file: String = "Sources/X/Test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`compound suite name`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`compound suite name Tests`.Unit {
    @Test
    func `Suite with compound name FooTests is flagged`() {
        let source = """
            @Suite struct MemoryBufferTests {}
            """
        let findings = Lint.Rule.`compound suite name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Suite with compound name on final class is flagged`() {
        let source = """
            @Suite final class MemoryBufferTests {}
            """
        let findings = Lint.Rule.`compound suite name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Suite with compound name on actor is flagged`() {
        let source = """
            @Suite actor MemoryBufferTests {}
            """
        let findings = Lint.Rule.`compound suite name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Suite with compound name on enum is flagged`() {
        let source = """
            @Suite enum MemoryBufferTests {}
            """
        let findings = Lint.Rule.`compound suite name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Suite named Test in a domain is permitted`() {
        let source = """
            extension MemoryBuffer { @Suite struct Test {} }
            """
        let findings = Lint.Rule.`compound suite name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Suite named Performance is flagged`() {
        let source = """
            @Suite struct Performance {}
            """
        let findings = Lint.Rule.`compound suite name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Suite named Unit is flagged`() {
        let source = """
            @Suite struct Unit {}
            """
        let findings = Lint.Rule.`compound suite name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-Suite compound struct is not flagged here`() {
        let source = """
            struct MemoryBufferTests {}
            """
        let findings = Lint.Rule.`compound suite name Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Suite named Integration is flagged`() {
        let source = """
            @Suite struct Integration {}
            """
        let findings = Lint.Rule.`compound suite name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Suite with three-token compound name is flagged`() {
        let source = """
            @Suite struct MyAPIChecks {}
            """
        let findings = Lint.Rule.`compound suite name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// MARK: - Non-Test suite names

extension Lint.Rule.`compound suite name Tests`.`Edge Case` {
    @Test
    func `backticked narrative Suite name is flagged`() {
        let source = """
            @Suite struct `compound identifier Tests` {}
            """
        let findings = Lint.Rule.`compound suite name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `backticked Suite name with multi-word narrative is flagged`() {
        let source = """
            @Suite struct `Sequence FlatMap Tests` {}
            """
        let findings = Lint.Rule.`compound suite name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `plain CamelCase Suite name remains flagged after backtick exemption`() {
        // Regression guard: the backtick exemption MUST NOT
        // short-circuit non-backticked CamelCase suite names.
        let source = """
            @Suite struct MemoryBufferTests {}
            """
        let findings = Lint.Rule.`compound suite name Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `top-level Test without a domain is flagged`() {
        let findings = Lint.Rule.`compound suite name Tests`.findings(
            in: "@Suite struct Test {}"
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`compound suite name Tests`.`Edge Case` {
    @Test
    func `the domain template with its categories is clean`() {
        let source = """
            extension URI {
                @Suite struct `URI Tests` {
                    @Suite struct Unit {}
                    @Suite struct `Edge Case` {}
                    @Suite struct Integration {}
                }
            }
            """
        #expect(Lint.Rule.`compound suite name Tests`.findings(in: source).isEmpty)
    }
}

extension Lint.Rule.`compound suite name Tests`.`Edge Case` {
    @Test
    func `the testing skill's shape with a named subdomain is clean`() {
        let source = """
            extension Parser {
                @Suite struct Parsing {
                    @Suite struct Unit {}
                    @Suite struct `Edge Case` {}
                    @Suite struct Integration {}
                }
            }
            extension Parser.Parsing.Unit {
                @Test func `parses an empty input`() {}
            }
            extension Lint.Rule {
                @Suite struct `comment in source Tests` {
                    @Suite struct Unit {}
                }
            }
            """
        #expect(Lint.Rule.`compound suite name Tests`.findings(in: source, file: "Tests/X Tests/Parser Tests.swift").isEmpty)
    }

    @Test
    func `a category added in an extension of the subdomain is clean`() {
        let source = """
            extension Parser.Parsing {
                @Suite struct `Edge Case` {}
            }
            """
        #expect(Lint.Rule.`compound suite name Tests`.findings(in: source).isEmpty)
    }

    @Test
    func `the single-word top-level fallback for a generic host is clean`() {
        let source = """
            @Suite struct `Index Tests` {
                @Suite struct Unit {}
                @Suite struct `Edge Case` {}
                @Suite struct Integration {}
            }
            """
        #expect(Lint.Rule.`compound suite name Tests`.findings(in: source).isEmpty)
    }

    @Test
    func `a fourth category inside a subdomain is flagged`() {
        let source = """
            extension Parser {
                @Suite struct Parsing {
                    @Suite struct Helpers {}
                    @Suite struct EdgeCase {}
                }
            }
            """
        #expect(Lint.Rule.`compound suite name Tests`.findings(in: source).count == 2)
    }

    @Test
    func `a concatenated tests name in a domain is still flagged`() {
        let source = """
            extension Parser {
                @Suite struct ParserTests {}
            }
            """
        #expect(Lint.Rule.`compound suite name Tests`.findings(in: source).count == 1)
    }

    @Test
    func `a category directly in a source type extension is still flagged`() {
        let source = """
            extension Parser {
                @Suite struct Unit {}
            }
            """
        #expect(Lint.Rule.`compound suite name Tests`.findings(in: source).count == 1)
    }

    @Test
    func `a multi-word or lower-case top-level backticked suite is still flagged`() {
        for name in ["`Memory Buffer Tests`", "`compound Tests`", "`Tests`", "`Index Checks`"] {
            let findings = Lint.Rule.`compound suite name Tests`.findings(in: "@Suite struct \(name) {}")
            #expect(findings.count == 1, "\(name)")
        }
    }
}
