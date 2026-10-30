import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Idiom

extension Lint.Rule {
    @Suite
    struct `statement where expression fits Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`statement where expression fits Tests` {
    static func findings(
        _ source: Swift::String,
        file: Swift::String = "Sources/Fixture/Fixture.swift"
    ) -> [Diagnostic.Record] {
        Lint.Rule.`statement where expression fits`
            .observe(Lint.Source.parsed(from: source, file: file), .warning)
            .findings
    }
}

extension Lint.Rule.`statement where expression fits Tests`.Unit {
    @Test
    func `an if else chain of returns is flagged once`() {
        let findings = Lint.Rule.`statement where expression fits Tests`.findings(
            """
            func f(_ value: Int) -> String {
                if value < 0 {
                    return "negative"
                } else if value == 0 {
                    return "zero"
                } else {
                    return "positive"
                }
            }
            """
        )
        #expect(findings.count == 1)
        #expect(findings[0].message.hasPrefix("[statement where expression fits] [SOURCE-EXPRESSION-OVER-STATEMENT]:"))
    }

    @Test
    func `assignments to one variable are flagged`() {
        let findings = Lint.Rule.`statement where expression fits Tests`.findings(
            """
            func f(_ flag: Bool) {
                let value: Int
                if flag {
                    value = 1
                } else {
                    value = 2
                }
                use(value)
            }
            """
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`statement where expression fits Tests`.`Edge Case` {
    @Test
    func `assignments to different variables are clean`() {
        let findings = Lint.Rule.`statement where expression fits Tests`.findings(
            "func f(_ flag: Bool) { if flag { a = 1 } else { b = 2 } }"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `an if without else is clean`() {
        let findings = Lint.Rule.`statement where expression fits Tests`.findings(
            "func f(_ flag: Bool) -> Int { if flag { return 1 }\n return 2 }"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `bare returns and multi-statement branches are clean`() {
        let findings = Lint.Rule.`statement where expression fits Tests`.findings(
            """
            func f(_ flag: Bool) {
                if flag { return } else { return }
            }
            func g(_ flag: Bool) -> Int {
                if flag { return 1 } else { log(); return 2 }
            }
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `if expressions are clean`() {
        let findings = Lint.Rule.`statement where expression fits Tests`.findings(
            "func f(_ flag: Bool) -> Int { let x = if flag { 1 } else { 2 }\n return if flag { x } else { 0 } }"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`statement where expression fits Tests`.Integration {
    @Test
    func `optional binding branches are flagged too`() {
        let findings = Lint.Rule.`statement where expression fits Tests`.findings(
            "func f(_ value: Int?) -> Int { if let value { return value } else { return 0 } }",
            file: "Tests/Fixture Tests/Fixture Tests.swift"
        )
        #expect(findings.count == 1)
    }
}
