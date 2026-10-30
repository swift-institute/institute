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

@testable import Institute_Linter_Rule_Platform

extension Lint.Rule {
    @Suite
    struct `dead case per platform Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`dead case per platform Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`dead case per platform`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`dead case per platform Tests`.Unit {
    @Test
    func `posix windows enum is flagged`() {
        let source = """
            public enum RawEncoding {
                case posix
                case windows
            }
            """
        let findings = Lint.Rule.`dead case per platform Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "dead case per platform")
        }
    }

    @Test
    func `posix windows enum inside a public extension is flagged`() {
        // Regression guard: a member of a `public extension` is public
        // API without carrying the keyword itself.
        let source = """
            public extension Foo {
                enum RawEncoding {
                    case posix
                    case windows
                }
            }
            """
        let findings = Lint.Rule.`dead case per platform Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `utf8 utf16 enum is flagged`() {
        let source = """
            public enum Encoding {
                case utf8
                case utf16
            }
            """
        let findings = Lint.Rule.`dead case per platform Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`dead case per platform Tests`.`Edge Case` {
    @Test
    func `domain alternatives enum is NOT flagged`() {
        let source = """
            public enum URLScheme {
                case http
                case https
                case ftp
            }
            """
        let findings = Lint.Rule.`dead case per platform Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `internal enum is NOT flagged`() {
        let source = """
            internal enum RawEncoding {
                case posix
                case windows
            }
            """
        let findings = Lint.Rule.`dead case per platform Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // MARK: - #21 defect 4: subset (not exact-set-equality) matching

    @Test
    func `platform pair plus an extra non-platform case still fires`() {
        let source = """
            public enum Encoding {
                case posix
                case windows
                case unknown
            }
            """
        let findings = Lint.Rule.`dead case per platform Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `macOS linux pair is flagged`() {
        let source = """
            public enum Encoding {
                case macOS
                case linux
            }
            """
        let findings = Lint.Rule.`dead case per platform Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `macOS windows pair is flagged`() {
        let source = """
            public enum Encoding {
                case macOS
                case windows
            }
            """
        let findings = Lint.Rule.`dead case per platform Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // MARK: - #21 defect 5: member-position `#if` was invisible

    @Test
    func `platform case guarded by member-position if os is flagged`() {
        let source = """
            public enum Encoding {
                #if os(Windows)
                case windows
                #else
                case posix
                #endif
            }
            """
        let findings = Lint.Rule.`dead case per platform Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
