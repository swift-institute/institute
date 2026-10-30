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

@testable import Institute_Linter_Rule_Memory

extension Lint.Rule {
    @Suite
    struct `noncopyable error Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`noncopyable error Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "Sources/X/Test.swift"
    )
        -> [Diagnostic.Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`noncopyable error`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`noncopyable error Tests`.Unit {
    @Test
    func `Error and noncopyable struct is flagged`() {
        let source = """
            struct MyError: Error, ~Copyable {}
            """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Error without noncopyable is permitted`() {
        let source = """
            struct MyError: Error {}
            """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `noncopyable without Error is permitted`() {
        let source = """
            struct Token: ~Copyable {}
            """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Error and noncopyable enum is flagged`() {
        let source = """
            enum MyError: Error, ~Copyable {
                case oops
            }
            """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Swift Error fully qualified is flagged`() {
        let source = """
            struct MyError: Swift.Error, ~Copyable {}
            """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `noncopyable struct with non-Error protocol is permitted`() {
        let source = """
            struct Token: Sendable, ~Copyable {}
            """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // #25 defect 5.

    @Test
    func `noncopyable protocol conforming to Error is flagged`() {
        let source = """
            protocol Failure: Error, ~Copyable {}
            """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Error added by a same-file extension is flagged`() {
        let source = """
            struct E: ~Copyable {}
            extension E: Error {}
            """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nested non-stdlib Module dot Error does not false-positive`() {
        let source = """
            struct E: MyModule.Error, ~Copyable {}
            """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `noncopyable class conforming to Error is flagged`() {
        let source = """
            final class MyError: Error, ~Copyable {}
            """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `qualified suppression spelling dot Copyable is recognized`() {
        let source = """
            struct MyError: Error, ~Swift.Copyable {}
            """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
