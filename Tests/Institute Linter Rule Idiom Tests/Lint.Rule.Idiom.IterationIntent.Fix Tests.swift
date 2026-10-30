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
import Linter_Rule_Testing
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Institute_Linter_Rule_Idiom

extension Lint.Rule {
    @Suite
    struct `counter loop iteration fix Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct `Round Trip` {}
        @Suite struct `Not Fixable` {}
    }
}

extension Lint.Rule.`counter loop iteration fix Tests` {
    /// The rewritten text, or `nil` when the rule declines to rewrite.
    static func fixed(_ source: String, file: String = "test.swift") -> String? {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`counter loop iteration`.rewritten(parsed)
    }

    /// Findings the rule reports for `source`.
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`counter loop iteration`.observe(parsed, .warning).findings
    }

    /// Asserts the self-round-trip property: `source` is flagged, the fix
    /// rewrites it, the rewrite parses without error, and re-linting the
    /// rewrite reports nothing for this rule.
    ///
    /// This is the whole contract a rewriter-backed rule owes the engine. A
    /// fix that produced unparseable text would be refused at run time; a fix
    /// whose output still fires would loop the fleet forever.
    static func roundTrips(
        _ source: String,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        #expect(
            !findings(in: source).isEmpty,
            "fixture must fire before it can round-trip",
            sourceLocation: sourceLocation
        )
        guard let output = fixed(source) else {
            Issue.record("expected a rewrite", sourceLocation: sourceLocation)
            return
        }
        #expect(
            !Parser.parse(source: output).hasError,
            "rewrite must parse: \(output)",
            sourceLocation: sourceLocation
        )
        #expect(
            findings(in: output).isEmpty,
            "rewrite must re-lint clean: \(output)",
            sourceLocation: sourceLocation
        )
    }
}

extension Lint.Rule.`counter loop iteration fix Tests`.`Round Trip` {
    @Test
    func `half-open counter loop climbs to forEach`() {
        let source = """
            func op(_ items: [Int]) {
                for i in 0..<items.count {
                    handle(items[i])
                }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
        #expect(
            Lint.Rule.`counter loop iteration fix Tests`
                .fixed(source)?.contains("(0..<items.count).forEach { i in") == true
        )
    }

    @Test
    func `closed counter loop climbs to forEach`() {
        let source = """
            func op(_ first: Int, _ last: Int) {
                for byte in first...last {
                    consume(byte)
                }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
    }

    @Test
    func `reversed range needs no second parenthesis`() {
        let source = """
            func op(_ n: Int) {
                for index in (0..<n).reversed() {
                    process(index)
                }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
        #expect(
            Lint.Rule.`counter loop iteration fix Tests`.fixed(source)?.contains("((0..<n)")
                == false
        )
    }

    @Test
    func `a multi-statement body is carried over verbatim`() {
        let source = """
            func op(_ n: Int) {
                for index in 0..<n {
                    let doubled = index * 2
                    record(doubled)
                }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
        let output = Lint.Rule.`counter loop iteration fix Tests`.fixed(source)
        #expect(output?.contains("let doubled = index * 2") == true)
        #expect(output?.contains("record(doubled)") == true)
    }
}

extension Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable` {
    /// Asserts the rule still fires but declines to rewrite — the loop stays
    /// a finding for a person to restructure.
    static func declines(
        _ source: String,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        #expect(
            !Lint.Rule.`counter loop iteration fix Tests`.findings(in: source).isEmpty,
            sourceLocation: sourceLocation
        )
        #expect(
            Lint.Rule.`counter loop iteration fix Tests`.fixed(source) == nil,
            sourceLocation: sourceLocation
        )
    }

    @Test
    func `a body containing break is left alone`() {
        Self.declines(
            """
            func op(_ n: Int) {
                for index in 0..<n {
                    if done(index) { break }
                    process(index)
                }
            }
            """
        )
    }

    @Test
    func `a body containing continue is left alone`() {
        Self.declines(
            """
            func op(_ n: Int) {
                for index in 0..<n {
                    if skip(index) { continue }
                    process(index)
                }
            }
            """
        )
    }

    @Test
    func `a body containing return is left alone`() {
        Self.declines(
            """
            func op(_ n: Int) -> Int? {
                for index in 0..<n {
                    if match(index) { return index }
                }
                return nil
            }
            """
        )
    }

    @Test
    func `a body containing try is left alone`() {
        Self.declines(
            """
            func op(_ n: Int) throws {
                for index in 0..<n {
                    try process(index)
                }
            }
            """
        )
    }

    @Test
    func `a body containing await is left alone`() {
        Self.declines(
            """
            func op(_ n: Int) async {
                for index in 0..<n {
                    await process(index)
                }
            }
            """
        )
    }

    @Test
    func `a where clause is left alone`() {
        Self.declines(
            """
            func op(_ n: Int) {
                for index in 0..<n where index.isMultiple(of: 2) {
                    process(index)
                }
            }
            """
        )
    }

    @Test
    func `a labelled loop is left alone`() {
        Self.declines(
            """
            func op(_ n: Int) {
                outer: for index in 0..<n {
                    process(index)
                }
            }
            """
        )
    }

    @Test
    func `a typed-throws loop neither fires nor is rewritten`() {
        let source = """
            func op(_ n: Int) throws(Failure) {
                for index in 0..<n {
                    try process(index)
                }
            }
            """
        #expect(Lint.Rule.`counter loop iteration fix Tests`.findings(in: source).isEmpty)
        #expect(Lint.Rule.`counter loop iteration fix Tests`.fixed(source) == nil)
    }

    @Test
    func `a non-range loop is not touched`() {
        let source = """
            func op(_ items: [Int]) {
                for item in items {
                    handle(item)
                }
            }
            """
        #expect(Lint.Rule.`counter loop iteration fix Tests`.findings(in: source).isEmpty)
        #expect(Lint.Rule.`counter loop iteration fix Tests`.fixed(source) == nil)
    }
}

extension Lint.Rule.`counter loop iteration fix Tests`.`Round Trip` {
    @Test
    func `a single-line body climbs too`() {
        let source = """
            func op(_ n: Int) {
                var sum = 0
                for i in 0..<n { sum += i }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
    }
}

extension Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable` {
    @Test
    func `a loop in a builder-attributed body is not rewritten`() {
        let source = """
            struct Page {
                @ViewBuilder
                func rows(_ n: Int) -> Body {
                    for i in 0..<n {
                        Row(i)
                    }
                }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable`.declines(source)
    }

    @Test
    func `a loop in an opaque-result body is not rewritten`() {
        let source = """
            struct Page {
                var body: some View {
                    for i in 0..<count {
                        Row(i)
                    }
                }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable`.declines(source)
    }

    @Test
    func `a loop in a bare trailing closure is not rewritten`() {
        let source = """
            func page(_ n: Int) {
                Stack(.vertical) {
                    for i in 0..<n {
                        Row(i)
                    }
                }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable`.declines(source)
    }
}

extension Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable` {
    /// A closure's parameter signature does not prove the closure is a plain
    /// function value. `init(@ListBuilder content: (Int) -> [String])` is
    /// called exactly this way, and a builder with a `buildExpression(_:
    /// Void)` overload accepts the rewritten `forEach` and renders nothing.
    @Test
    func `a loop in a parameterized closure is not rewritten`() {
        let source = """
            let reader = Reader { proxy in
                for i in 0..<3 {
                    "row \\(i) at \\(proxy)"
                }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable`.declines(source)
    }

    /// The accepted false refusal that pays for the fixture above: a closure
    /// that plainly is a function value keeps its loop as a finding.
    @Test
    func `a loop in a plain closure inside a builder body is refused too`() {
        let source = """
            struct Page {
                @ViewBuilder
                func rows(_ n: Int) -> Body {
                    Row(measure { size in
                        for i in 0..<n {
                            size.widen(i)
                        }
                    })
                }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable`.declines(source)
    }

    @Test
    func `a comment after the sequence is not deleted`() {
        let source = """
            func op(_ n: Int) {
                var sum = 0
                for i in 0 ..< n /* inclusive of overflow guard */ {
                    sum += i
                }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable`.declines(source)
    }

    @Test
    func `a comment between for and the pattern is not deleted`() {
        let source = """
            func op(_ n: Int) {
                var sum = 0
                for /* index into table */ j in 0..<n { sum += j }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable`.declines(source)
    }

    @Test
    func `a line comment before the loop brace is not deleted`() {
        let source = """
            func op(_ n: Int) {
                var sum = 0
                for i in 0..<n  // running total
                {
                    sum += i
                }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable`.declines(source)
    }
}

extension Lint.Rule.`counter loop iteration fix Tests`.`Round Trip` {
    /// The guard is about comments, not about whitespace: an unusually spaced
    /// header still climbs.
    @Test
    func `extra whitespace in the loop header still climbs`() {
        let source = """
            func op(_ n: Int) {
                var sum = 0
                for   i   in   0 ..< n   {
                    sum += i
                }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
    }

    /// A comment INSIDE the body is carried over with its statements, and is
    /// not what the header guard refuses.
    @Test
    func `a comment inside the body is carried over`() {
        let source = """
            func op(_ n: Int) {
                var sum = 0
                for i in 0..<n {
                    // accumulate
                    sum += i
                }
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
        #expect(
            Lint.Rule.`counter loop iteration fix Tests`.fixed(source)?.contains("// accumulate")
                == true
        )
    }
}

extension Lint.Rule.`counter loop iteration fix Tests`.`Round Trip` {
    /// Positive control for #49: a plain body with no ownership-annotated
    /// parameter in scope still climbs to `forEach`, matching every other
    /// round-trip fixture in this file. Guards against a predicate that
    /// over-refuses generally rather than specifically on ownership.
    @Test
    func `a plain body with no ownership-annotated parameter still climbs`() {
        let source = """
            func op(lhs: [Int], rhs: [Int]) -> [Int] {
                var result = lhs
                for i in 0..<lhs.count {
                    result[i] = lhs[i] + rhs[i]
                }
                return result
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
    }

    /// Near-miss for #49: `rhs` carries an explicit `borrowing` modifier, but
    /// the loop body never references it — only `lhs`, an ordinary parameter,
    /// appears inside the loop. The rewrite may proceed: the refusal is keyed
    /// to a REFERENCE inside the body, not to the parameter's mere presence
    /// in the signature.
    @Test
    func `an unreferenced borrowing parameter does not block the rewrite`() {
        let source = """
            func op(lhs: [Int], rhs: borrowing [Int]) -> [Int] {
                var result = lhs
                for i in 0..<lhs.count {
                    result[i] = lhs[i] * 2
                }
                return result
            }
            """
        Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
    }
}

extension Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable` {
    /// #49 witness reproduction (swift-affine-geometry PR #5,
    /// head 499186f): a `borrowing` parameter referenced inside the loop
    /// body. The `forEach` translation would move the reference into a
    /// closure — a distinct activation frame a `borrowing` parameter is
    /// guaranteed not to escape — and fails at typecheck with `'rhs' is
    /// borrowed and cannot be consumed`, which the fix pipeline's re-parse
    /// guard cannot catch. The diagnostic still fires; only the rewrite
    /// declines.
    @Test
    func `a borrowing parameter referenced in the body blocks the rewrite`() {
        Self.declines(
            """
            func op(lhs: [Int], rhs: borrowing [Int]) -> [Int] {
                var result = lhs
                for i in 0..<lhs.count {
                    result[i] = lhs[i] - rhs[i]
                }
                return result
            }
            """
        )
    }

    /// The `consuming` counterpart: a `consuming` parameter referenced in the
    /// body is refused for the same reason a `borrowing` one is — neither
    /// binding may be captured by the `forEach` closure the rewrite would
    /// introduce.
    @Test
    func `a consuming parameter referenced in the body blocks the rewrite`() {
        Self.declines(
            """
            func op(_ n: Int, extra: consuming [Int]) {
                for i in 0..<n {
                    use(extra)
                }
            }
            """
        )
    }
}
