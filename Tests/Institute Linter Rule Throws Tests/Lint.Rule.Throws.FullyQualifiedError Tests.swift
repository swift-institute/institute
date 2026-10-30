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

@testable import Institute_Linter_Rule_Throws

extension Lint.Rule {
    @Suite
    struct `fully qualified error in typed throws Tests` {}
}

extension Lint.Rule.`fully qualified error in typed throws Tests` {
    static func findings(in source: Swift::String) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: "test.swift")
        return Lint.Rule.`fully qualified error in typed throws`
            .observe(parsed, .warning).findings
    }

    @Test
    func `bare nested Error shorthand is flagged`() {
        #expect(Self.findings(in: "func read() throws(Error) {}").count == 1)
    }

    @Test
    func `complete generic owner path is accepted`() {
        let source = """
            func read<Element>() throws(Algebra.Field<Element>.Error) {}
            """
        #expect(Self.findings(in: source).isEmpty)
    }

    @Test
    func `closure function type is checked`() {
        let source = "let body: () throws(Error) -> Void"
        #expect(Self.findings(in: source).count == 1)
    }

    @Test
    func `do throws is checked`() {
        let source = "do throws(Error) {} catch {}"
        #expect(Self.findings(in: source).count == 1)
    }

    @Test
    func `standalone descriptive error type is accepted`() {
        #expect(Self.findings(in: "func read() throws(ReadError) {}").isEmpty)
    }
}
