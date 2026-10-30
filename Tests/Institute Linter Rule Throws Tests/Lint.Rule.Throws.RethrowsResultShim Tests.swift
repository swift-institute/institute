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

@testable import Institute_Linter_Rule_Throws

extension Lint.Rule {
    @Suite
    struct `result wrapper for rethrows shim Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`result wrapper for rethrows shim Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "Sources/X/Test.swift"
    )
        -> [Diagnostic.Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`result wrapper for rethrows shim`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`result wrapper for rethrows shim Tests`.Unit {
    @Test
    func `try inside map closure is flagged`() {
        let source = """
            let result = items.map { try transform($0) }
            """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `try inside compactMap closure is flagged`() {
        let source = """
            let result = items.compactMap { try transform($0) }
            """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `try inside filter closure is flagged`() {
        let source = """
            let result = items.filter { try predicate($0) }
            """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `map without try is not flagged`() {
        let source = """
            let result = items.map { transform($0) }
            """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `try with question mark is not flagged`() {
        let source = """
            let result = items.map { try? transform($0) }
            """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `try with bang is not flagged`() {
        let source = """
            let result = items.map { try! transform($0) }
            """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `result-wrapper pattern is permitted (no try inside closure)`() {
        let source = """
            let results = items.map { input -> Result<T, E> in
                Result { try transform(input) }
            }
            """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        // The `try` is inside the inner Result init's closure (nested), our
        // visitor skips into nested closures so the inner `try` belongs to
        // the inner closure (which is not a known rethrows method on `Result`).
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`result wrapper for rethrows shim Tests`.`Edge Case` {
    @Test
    func `non-stdlib rethrows method (custom name) is not flagged`() {
        let source = """
            let result = builder.processEach { try op($0) }
            """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `forEach with try is flagged`() {
        let source = """
            items.forEach { try doIt($0) }
            """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `closure with explicit typed-throws annotation is not flagged (bug 3a fix)`() {
        let source = """
            let result = try base.map { value throws(MyError) in try transform(value) }
            """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        // The closure carries `throws(MyError)`; stdlib `rethrows` accepts
        // only untyped-throws closures. The call site is invoking a
        // typed-throws institute API, not stdlib rethrows.
        #expect(findings.isEmpty)
    }

    @Test
    func `Tagged-style typed-throws closure is not flagged (bug 3a fix)`() {
        let source = """
            try base.map { ordinal throws(Ordinal.Error) in try ordinal.successor.exact() }
            """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `try inside do-catch with typed-only catch is still flagged (not materializing, #19)`() {
        let source = """
            let results = items.map { input -> Result<Int, MyError> in
                do {
                    return .success(try transform(input))
                } catch let error as MyError {
                    return .failure(error)
                }
            }
            """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        // A typed-only catch (`catch let error as MyError`) is not catch-all:
        // any error that doesn't match `MyError` propagates past it uncaught.
        // Per the #19 defect-3 ruling (coordinator adjudication, 2026-07-30),
        // materialization requires at least one catch-all clause, so this
        // shape does NOT materialize and the rule MUST still fire. Positive
        // control for that ruling.
        #expect(findings.count == 1)
    }

    @Test
    func `try inside do-catch that rethrows is still flagged (bug 3b boundary)`() {
        let source = """
            let result = items.map { input -> Int in
                do {
                    return try transform(input)
                } catch {
                    throw error
                }
            }
            """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        // The catch re-throws (`throw error`) so the closure DOES
        // propagate; not the Result-materialization pattern, the rule
        // should still fire.
        #expect(findings.count == 1)
    }
}
