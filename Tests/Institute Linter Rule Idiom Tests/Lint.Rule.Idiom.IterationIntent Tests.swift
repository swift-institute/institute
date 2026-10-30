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

@testable import Institute_Linter_Rule_Idiom

extension Lint.Rule {
    @Suite
    struct `counter loop iteration Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`counter loop iteration Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`counter loop iteration`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`counter loop iteration Tests`.Unit {
    @Test
    func `counter loop with 0 to n is flagged`() {
        let source = """
            func op(_ items: [Int]) {
                for i in 0..<items.count {
                    handle(items[i])
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "counter loop iteration")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `counter loop with non-zero start is flagged`() {
        let source = """
            func op(_ n: Int) {
                for index in 1..<n {
                    process(index)
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `counter loop with closed range is flagged`() {
        let source = """
            func op(_ n: Int) {
                for i in 0...n {
                    use(i)
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple counter loops each flagged`() {
        let source = """
            func op() {
                for i in 0..<10 { use(i) }
                for j in 0..<20 { use(j) }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `reversed half-open range is flagged`() {
        // #24 nit: for i in (0..<n).reversed() was missed — the sequence
        // is a .reversed() call, not a bare range expression.
        let source = """
            func op(_ n: Int) {
                for i in (0..<n).reversed() {
                    use(i)
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `reversed closed range is flagged`() {
        let source = """
            func op(_ n: Int) {
                for i in (0...n).reversed() {
                    use(i)
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `message does not claim the predicate is limited to index counters`() {
        // #24 nit: the predicate fires on any identifier-pattern range,
        // including a meaningfully-named non-index variable
        // (`for byte in first...last`); the message must not overstate a
        // narrower "index counter only" scope.
        let source = """
            func op(_ first: Int, _ last: Int) {
                for byte in first...last {
                    use(byte)
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(!findings[0].message.contains("counter is mechanism"))
        }
    }
}

extension Lint.Rule.`counter loop iteration Tests`.`Edge Case` {
    @Test
    func `direct iteration over collection is NOT flagged`() {
        let source = """
            func op(_ items: [Int]) {
                for element in items {
                    handle(element)
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `enumerated iteration is NOT flagged`() {
        let source = """
            func op(_ items: [Int]) {
                for (offset, element) in items.enumerated() {
                    handle(offset, element)
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stride iteration is NOT flagged`() {
        let source = """
            func op(_ total: Int) {
                for batch in stride(from: 0, to: total, by: 8) {
                    process(batch)
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `forEach call is NOT flagged`() {
        let source = """
            func op(_ items: [Int]) {
                items.forEach { handle($0) }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `reversed collection (not a range) is NOT flagged`() {
        let source = """
            func op(_ items: [Int]) {
                for item in items.reversed() {
                    handle(item)
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `tuple pattern with range is NOT flagged - destructured form`() {
        // Tuple pattern doesn't fit the counter shape.
        let source = """
            func op() {
                for (a, b) in zip(0..<3, ["a", "b", "c"]) {
                    handle(a, b)
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

// [IMPL-033] typed-throws loop recognition — ruled
// swift-institute/.github#90 comment 5150641576 item 1 (batch-1 backlog,
// comment 5150595934, W1-E entry). `Sequence.forEach(_:)` is `rethrows`
// and erases `throws(E)`, so a counter loop whose body performs a `try`
// inside a `throws(E)` function is the lawful spelling.
extension Lint.Rule.`counter loop iteration Tests`.`Edge Case` {
    @Test
    func `typed-throws function with throwing loop body is NOT flagged`() {
        let source = """
            func op(_ items: [Int]) throws(Failure) {
                for i in 0..<items.count {
                    try handle(items[i])
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typed-throws initializer with throwing loop body is NOT flagged`() {
        let source = """
            struct Holder {
                init(_ items: [Int]) throws(Failure) {
                    for i in 0..<items.count {
                        try handle(items[i])
                    }
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Near-miss 1: typed throws, but the body never throws — ordinary
    // mechanism, `forEach` erases nothing. Still fires.
    @Test
    func `typed-throws function with non-throwing loop body is still flagged`() {
        let source = """
            func op(_ items: [Int]) throws(Failure) {
                for i in 0..<items.count {
                    handle(items[i])
                }
                try finish()
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Near-miss 2: the body throws, but the function is UNTYPED `throws` —
    // `forEach`'s `rethrows` erases nothing that isn't already `any Error`.
    @Test
    func `untyped-throws function with throwing loop body is still flagged`() {
        let source = """
            func op(_ items: [Int]) throws {
                for i in 0..<items.count {
                    try handle(items[i])
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Near-miss 3: `try?` discards the typed error, so nothing is preserved.
    @Test
    func `typed-throws function whose loop body uses try-optional is still flagged`() {
        let source = """
            func op(_ items: [Int]) throws(Failure) {
                for i in 0..<items.count {
                    _ = try? handle(items[i])
                }
                try finish()
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Near-miss 4: the loop's DIRECTLY enclosing context is an untyped
    // closure nested inside a `throws(E)` function — the exemption must not
    // leak through the closure boundary.
    @Test
    func `loop inside an untyped closure within a typed-throws function is still flagged`() {
        let source = """
            func op(_ items: [Int]) throws(Failure) {
                run { () throws -> Void in
                    for i in 0..<items.count {
                        try handle(items[i])
                    }
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Positive control: a typed-throws CLOSURE body is itself a lawful
    // typed-throws context.
    @Test
    func `typed-throws closure with throwing loop body is NOT flagged`() {
        let source = """
            let run = { (items: [Int]) throws(Failure) -> Void in
                for i in 0..<items.count {
                    try handle(items[i])
                }
            }
            """
        let findings = Lint.Rule.`counter loop iteration Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
