import Lint
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Institute_Linter_Rule_Idiom

@Suite
struct `for loop in result builder Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
    @Suite struct `Positive Cases` {}
    @Suite struct `Negative Cases` {}
    @Suite struct `Callee Patterns` {}
    @Suite struct `Edge Cases` {}
    @Suite struct `Severity` {}
    @Suite struct `Allowlist` {}
}

extension `for loop in result builder Tests` {
    static func findings(
        in source: Swift::String,
        rule: Lint.Rule = Lint.Rule.`for loop in result builder`,
        severity: Diagnostic.Severity = .warning,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return rule.observe(parsed, severity).findings
    }
}

extension `for loop in result builder Tests`.`Positive Cases` {
    @Test
    func `Array with for-loop is flagged`() {
        let source = """
            let a = Array<Int> {
                for i in 0..<100 {
                    i
                }
            }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "for loop in result builder")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `Set with for-loop is flagged`() {
        let source = """
            let s = Set<Int> {
                for i in 0..<10 {
                    i
                }
            }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Bitset with for-loop is flagged`() {
        let source = """
            let b = Bitset {
                for i in 0..<10 {
                    i
                }
            }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `For-loop nested inside an if-statement is flagged`() {
        let source = """
            let a = Array<Int> {
                if condition {
                    for i in 0..<100 {
                        i
                    }
                }
            }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Multiple for-loops in same builder body are each flagged`() {
        let source = """
            let a = Array<Int> {
                for i in 0..<10 { i }
                for j in 10..<20 { j }
            }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)

        #expect(findings.count == 1)
    }
}

extension `for loop in result builder Tests`.`Negative Cases` {
    @Test
    func `Array with Sequence overload is NOT flagged`() {
        let source = """
            let a = Array<Int> {
                0..<100
            }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Array with literal statements is NOT flagged`() {
        let source = """
            let a = Array<Int> {
                1
                2
                3
            }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `For-loop outside any builder context is NOT flagged`() {
        let source = """
            var a: [Int] = []
            for i in 0..<100 {
                a.append(i)
            }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Custom non-allowlisted Builder with for-loop is NOT flagged`() {
        let source = """
            let m = MyCustomThing {
                for i in 0..<10 {
                    i
                }
            }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `For-loop in nested closure NOT inside outer builder is NOT flagged`() {

        let source = """
            let a = Array<Int> {
                someFunction {
                    for i in 0..<10 {
                        print(i)
                    }
                }
            }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension `for loop in result builder Tests`.`Callee Patterns` {
    @Test
    func `Generic Array callsite is recognized`() {
        let source = """
            let a = Array<Int> { for i in 0..<10 { i } }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Module-qualified Swift_Array callsite is recognized`() {
        let source = """
            let a = Swift.Array<Int> { for i in 0..<10 { i } }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Nested Buffer_Linear callsite is recognized`() {
        let source = """
            let b = Buffer<Int>.Linear { for i in 0..<10 { i } }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Nested Tree_N callsite is recognized`() {
        let source = """
            let t = Tree<Int>.N<2> { for i in 0..<10 { i } }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Nested Tree_Binary callsite is recognized`() {
        let source = """
            let t = Tree<Int>.Binary { for i in 0..<10 { i } }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Nested Set_Ordered callsite is recognized`() {
        let source = """
            let s = Set<Int>.Ordered { for i in 0..<10 { i } }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Heap callsite with order argument is recognized`() {
        let source = """
            let h = Heap<Int>(order: .ascending) {
                for i in 0..<10 {
                    i
                }
            }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension `for loop in result builder Tests`.`Edge Cases` {
    @Test
    func `Empty file produces no findings`() {
        let findings = `for loop in result builder Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }

    @Test
    func `For-loop in string literal is NOT flagged`() {
        let source = """
            let s = "Array<Int> { for i in 0..<10 { i } }"
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `For-loop in comment is NOT flagged`() {
        let source = """
            // Don't write Array<Int> { for i in 0..<10 { i } }
            let a = 42
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Empty Array builder body is NOT flagged`() {
        let source = """
            let a = Array<Int> {}
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Nested Array builders both with for-loops are both flagged`() {

        let source = """
            let a = Array<[Int]> {
                for i in 0..<3 { i }
                Array<Int> {
                    for j in 0..<10 { j }
                }
            }
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `Allowlisted callee without trailing closure is NOT flagged`() {

        let source = """
            let a = Array(repeating: 0, count: 10)
            """
        let findings = `for loop in result builder Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension `for loop in result builder Tests`.Severity {
    @Test
    func `Default severity is warning`() {
        #expect(Lint.Rule.`for loop in result builder`.severity.default == .warning)
    }

    @Test
    func `Custom severity is honored`() {
        let source = """
            let a = Array<Int> { for i in 0..<10 { i } }
            """
        let findings = `for loop in result builder Tests`.findings(
            in: source,
            severity: .error
        )
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].severity == .error)
        }
    }
}

extension `for loop in result builder Tests`.Allowlist {
    @Test
    func `Default allowlist contains the 18 institute Builder names`() {
        let allowlist = `result builder for loop default allowlist`
        #expect(allowlist.contains("Array"))
        #expect(allowlist.contains("Buffer.Linear"))
        #expect(allowlist.contains("Tree.N"))
        #expect(allowlist.contains("Set.Ordered"))
        #expect(allowlist.contains("Heap"))
    }

    @Test
    func `Empty allowlist suppresses all findings`() {
        let source = """
            let a = Array<Int> { for i in 0..<10 { i } }
            """
        let rule = Lint.Rule.`for loop in result builder`(allowlist: [])
        let findings = `for loop in result builder Tests`.findings(in: source, rule: rule)
        #expect(findings.isEmpty)
    }

    @Test
    func `Consumer-extended allowlist catches custom Builders`() {
        let source = """
            let m = MyCustomBuilder<Int> { for i in 0..<10 { i } }
            """
        let rule = Lint.Rule.`for loop in result builder`(allowlist: ["MyCustomBuilder"])
        let findings = `for loop in result builder Tests`.findings(in: source, rule: rule)
        #expect(findings.count == 1)
    }
}
