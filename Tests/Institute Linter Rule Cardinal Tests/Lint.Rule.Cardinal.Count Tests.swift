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

@testable import Institute_Linter_Rule_Cardinal

extension Lint.Rule {
    @Suite
    struct `count minus one Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct `Evasion` {}
        @Suite struct `Negative` {}
    }
}

extension Lint.Rule.`count minus one Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`count minus one`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`count minus one Tests`.Unit {
    @Test
    func `Member-access seq.count - 1 is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = seq.count - 1")
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "count minus one")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `Member-access on local arr.count - 1 is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = arr.count - 1")
        #expect(findings.count == 1)
    }

    @Test
    func `Custom severity is honored`() {
        let source = "let n = seq.count - 1"
        let parsed = Lint.Source.parsed(from: source)
        let findings = Lint.Rule.`count minus one`.observe(parsed, .error).findings
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].severity == .error)
        }
    }
}

extension Lint.Rule.`count minus one Tests`.Evasion {
    @Test
    func `Paren-wrapped (seq.count - 1) is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = (seq.count - 1)")
        #expect(findings.count == 1)
    }

    @Test
    func `Cast-outside Double(seq.count) - 1 is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(
            in: "let n = Double(seq.count) - 1"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Algebraic-flip i + 1 less-than seq.count is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "if i + 1 < seq.count { }")
        #expect(findings.count == 1)
    }

    @Test
    func `Algebraic-flip distance + 1 equals seq.count is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(
            in: "if distance + 1 == seq.count { }"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Algebraic-flip seq.count greater-than i + 1 is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "if seq.count > i + 1 { }")
        #expect(findings.count == 1)
    }

    @Test
    func `Algebraic-flip with 1 + i (commutative) is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "if 1 + i < seq.count { }")
        #expect(findings.count == 1)
    }

    @Test
    func `Operand-reorder seq.count - i - 1 is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = seq.count - i - 1")
        #expect(findings.count >= 1)
    }

    @Test
    func `Comments-as-code is NOT flagged`() {
        let source = """
            // seq.count - 1 is the canonical anti-pattern (this is just prose)
            let x = 42
            """
        let findings = Lint.Rule.`count minus one Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`count minus one Tests`.Negative {
    @Test
    func `seq.count - 2 is NOT flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = seq.count - 2")
        #expect(findings.isEmpty)
    }

    @Test
    func `accountCount - 1 (non-count identifier) is NOT flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = accountCount - 1")
        #expect(findings.isEmpty)
    }

    @Test
    func `seq.count + 1 is NOT flagged outside comparison context`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = seq.count + 1")
        #expect(findings.isEmpty)
    }

    @Test
    func `i + 1 < limit is NOT flagged when count absent`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "if i + 1 < limit { }")
        #expect(findings.isEmpty)
    }

    @Test
    func `Empty file produces no findings`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }

    @Test
    func `Bare count - 1 (non-member-access) is NOT flagged`() {
        // Pre-narrowing the rule walked tokens for any identifier `count`;
        // post-narrowing only `<expr>.count` member-access form fires.
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = count - 1")
        #expect(findings.isEmpty)
    }

    @Test
    func `Local binding let count = i; count - 1 is NOT flagged`() {
        let source = """
            let count = i
            let last = count - 1
            """
        let findings = Lint.Rule.`count minus one Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Loop variable for count in 0..<n; count - 1 is NOT flagged`() {
        let source = """
            for count in 0..<n {
                _ = count - 1
            }
            """
        let findings = Lint.Rule.`count minus one Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `grid-rows-count-dot-height - 1 (count unrelated to the subtraction) is NOT flagged`() {
        // Boundary guard: `.count` appears somewhere in the left operand,
        // but the `- 1` applies to `.height`, not `.count` — the deep
        // search must not fire on any `.count` mention anywhere in the
        // subtree.
        let findings = Lint.Rule.`count minus one Tests`.findings(
            in: "let n = grid[rows.count].height - 1"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func
        `i plus 1 less-than limits-keys-count (comparison side unrelated to count) is NOT flagged`()
    {
        let findings = Lint.Rule.`count minus one Tests`.findings(
            in: "if i + 1 < limits[keys.count] { }"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`count minus one Tests`.`Edge Case` {
    @Test
    func `seq.count - 1 inside string literal is NOT flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: #"let s = "seq.count - 1""#)
        #expect(findings.isEmpty)
    }

    @Test
    func `Nested expression let n = (a + b) + (seq.count - 1) is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(
            in: "let n = (a + b) + (seq.count - 1)"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `Multi-line nested algebraic-flip is flagged`() {
        let source = """
            if i + 1
                < seq.count {
                doSomething()
            }
            """
        let findings = Lint.Rule.`count minus one Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// Count-vs-count comparison false positive — ruled
// swift-institute/.github#90 comment 5150641576 item 1(b). Predicate 2
// (algebraic flip) targets an INDEX compared against a count; when both
// sides are cardinalities the expression compiles unchanged under a typed
// `Cardinal`, so [INFRA-200]'s "the typed form would not compile" test
// does not hold.
extension Lint.Rule.`count minus one Tests`.`Negative` {
    @Test
    func `count == count + 1 assertion comparison is NOT flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(
            in: "#expect(secure.middleware.count == plain.middleware.count + 1)"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `count + 1 == count with the plus on the left is NOT flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(
            in: "#expect(plain.middleware.count + 1 == secure.middleware.count)"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `count less-than count + 1 is NOT flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(
            in: "let ok = a.count < b.count + 1"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `paren-wrapped count + 1 against a count is NOT flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(
            in: "let ok = a.count == (b.count) + 1"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`count minus one Tests`.`Edge Case` {
    // Near-miss controls: real index arithmetic must still fire after the
    // count-vs-count refinement.
    @Test
    func `index + 1 compared against a count is still flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let ok = i + 1 < seq.count")
        #expect(findings.count == 1)
    }

    @Test
    func `count compared against index + 1 is still flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let ok = seq.count == i + 1")
        #expect(findings.count == 1)
    }

    @Test
    func `member-access subscript with count minus one is still flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(
            in: "let last = array[array.count - 1]"
        )
        #expect(findings.count == 1)
    }
}
