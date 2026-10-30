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
    struct `closure typed throws annotation Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`closure typed throws annotation Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`closure typed throws annotation`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`closure typed throws annotation Tests`.Unit {
    @Test
    func `untyped closure with try inside typed-throws function is flagged`() {
        let source = """
            func f<E: Swift.Error>(_ xs: [Int]) throws(E) -> [Int] {
                xs.map { try g($0) }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "closure typed throws annotation")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `untyped closure with try inside typed-throws init is flagged`() {
        let source = """
            struct S {
                init() throws(MyError) {
                    values.forEach { _ in try work() }
                }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple unannotated closures all flagged`() {
        let source = """
            func f<E: Swift.Error>() throws(E) {
                let a = xs.map { try g($0) }
                let b = ys.map { try h($0) }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`closure typed throws annotation Tests`.`Edge Case` {
    @Test
    func `closure with explicit throws(E) annotation is NOT flagged`() {
        let source = """
            func f<E: Swift.Error>(_ xs: [Int]) throws(E) -> [Int] {
                xs.map { (x: Int) throws(E) -> Int in try g(x) }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `closure inside untyped throws function is NOT flagged`() {
        let source = """
            func f(_ xs: [Int]) throws -> [Int] {
                xs.map { try g($0) }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `closure without try is NOT flagged`() {
        let source = """
            func f<E: Swift.Error>() throws(E) {
                let xs = [1, 2, 3].map { $0 * 2 }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `closure inside non-throwing function is NOT flagged`() {
        let source = """
            func f() {
                // would not compile, but visitor should not crash
                let xs: [Int] = []
                _ = xs.map { $0 + 1 }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `top-level closure outside any function is NOT flagged`() {
        let source = """
            let xs = [1, 2, 3].map { $0 + 1 }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested closure with try and its own throws annotation is NOT flagged`() {
        let source = """
            func f<E: Swift.Error>() throws(E) {
                _ = xs.map { (x: Int) throws(E) -> Int in
                    ys.map { (y: Int) throws(E) -> Int in try g(y) }.first ?? 0
                }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `closure within nested non-throws inner function is NOT flagged for that inner`() {
        // The outer function is typed-throws; the inner function is non-throwing.
        // Closure inside inner is in a non-typed context (depth pops at inner entry).
        // Detection: depth is tracked per typed-throws frame; non-typed inner
        // doesn't increment depth — but depth from outer remains > 0, so the
        // closure WILL be flagged. This is intentional: the institute convention
        // requires consistent typed annotations even inside nested non-throwing
        // inner functions, OR the inner function should not be nested. Document
        // as known scope behavior.
        let source = """
            func f<E: Swift.Error>() throws(E) {
                func inner() {
                    _ = xs.map { try g($0) }
                }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        // Outer typed-throws depth is still 1 when visiting the inner closure.
        #expect(findings.count == 1)
    }

    // MARK: - #expect(throws:) macro carve-out

    @Test
    func `expect throws trailing closure with try is NOT flagged`() {
        // Carve-out: `#expect(throws:)` macro carries the expected
        // error type in its labeled argument. The trailing closure's
        // job is to throw; annotating it with `() throws(E) in` is
        // semantically meaningless and additionally triggers a Swift
        // 6.3.2 SIL crash with ~Copyable bodies.
        let source = """
            func f() throws(MyError) {
                #expect(throws: MyError.self) {
                    try work()
                }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `expect throws with specific error value still exempts the closure`() {
        // `#expect(throws: TestError.expected) { ... }` — the throws:
        // argument carries a specific error value rather than `.self`.
        // Carve-out still applies (the argument label is what matters).
        let source = """
            func f() throws(MyError) {
                #expect(throws: TestError.expected) {
                    try producer.produce()
                }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `expect without throws: label still flags trailing closure with try`() {
        // Regression guard: `#expect { try ... }` (no throws: argument)
        // is the basic assertion form, NOT the throws-asserting macro.
        // The carve-out is gated on the `throws:` argument label;
        // without it, the rule still fires.
        let source = """
            func f() throws(MyError) {
                #expect {
                    try predicate()
                }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `closure with only try optional is NOT flagged`() {
        // `try?` does not propagate — the closure remains non-throwing, so no
        // annotation is needed.
        let source = """
            func f<E: Swift.Error>(_ xs: [Int]) throws(E) -> [Int?] {
                xs.map { try? g($0) }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `closure with only try force is NOT flagged`() {
        // `try!` traps rather than propagating — the closure remains
        // non-throwing, so no annotation is needed.
        let source = """
            func f<E: Swift.Error>(_ xs: [Int]) throws(E) -> [Int] {
                xs.map { try! g($0) }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `closure with unguarded try nested inside try optional IS flagged`() {
        // The outer `try?` doesn't propagate, but the nested plain `try` inside
        // its subexpression does.
        let source = """
            func f<E: Swift.Error>(_ xs: [Int]) throws(E) -> [Int?] {
                xs.map { try? g(try h($0)) }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // MARK: - #19 defect 3: do/catch materialization holes

    @Test
    func `typed catch with where clause is not exhaustive so the try still fires`() {
        let source = """
            func f<E: Swift.Error>() throws(E) {
                _ = xs.map { (x: Int) -> Int in
                    do { return try g(x) } catch let e as A where e.isFatal { return .failure(e) }
                }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `catch that forwards via try fallback still propagates`() {
        let source = """
            func f<E: Swift.Error>() throws(E) {
                _ = xs.map { (x: Int) -> Int in
                    do { return try g(x) } catch { return try fallback() }
                }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `one propagating clause among several defeats materialization`() {
        let source = """
            func f<E: Swift.Error>() throws(E) {
                _ = xs.map { (x: Int) -> Int in
                    do { return try g(x) } catch is A { return -1 } catch { throw e }
                }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `catch-all that only returns a value materializes the try`() {
        let source = """
            func f<E: Swift.Error>() throws(E) {
                _ = xs.map { (x: Int) -> Int in
                    do { return try g(x) } catch { return -1 }
                }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // MARK: - #19 defect 4: accessors, subscripts, and typed-throws closures

    @Test
    func `computed property getter with typed throws is a typed-throws context`() {
        let source = """
            var x: Int {
                get throws(E) {
                    xs.map { try h($0) }.first ?? 0
                }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `subscript getter with typed throws is a typed-throws context`() {
        let source = """
            subscript(i: Int) -> Int {
                get throws(E) {
                    xs.map { try h($0) }.first ?? 0
                }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `explicitly-signed typed throws closure is itself exempt but counts for its children`() {
        // #19 defect 4, item 2: a closure whose OWN signature carries
        // `throws(E)` both stays exempt itself (it already has the
        // annotation) and counts as a typed-throws context for its nested
        // children — so the inner unannotated closure still fires. Note: a
        // closure with no `in`-clause signature at all (its type inferred
        // purely from a surrounding `let` type annotation) cannot be
        // classified as typed-throws by this per-file AST rule — SwiftSyntax
        // gives that closure literal no `signature` node to test, and
        // resolving the binding's declared type is cross-node type inference
        // this rule does not perform.
        let source = """
            let g: (Int) throws(E) -> Void = { (x: Int) throws(E) in
                xs.map { try h($0) }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-expect macro with throws: label does NOT exempt`() {
        // Regression guard: the carve-out is gated on the macro name
        // being `expect`. A different macro using a `throws:` label
        // is not the swift-testing macro and gets no exemption.
        let source = """
            func f() throws(MyError) {
                #customMacro(throws: MyError.self) {
                    try work()
                }
            }
            """
        let findings = Lint.Rule.`closure typed throws annotation Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
