import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Idiom

extension Lint.Rule {
    @Suite
    struct `literal conformance shadows validating init Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`literal conformance shadows validating init Tests` {
    static func findings(in source: Swift::String) -> [Diagnostic.Record] {
        Lint.Rule.`literal conformance shadows validating init`
            .observe(Lint.Source.parsed(from: source, file: "Sources/Fixture/Value.swift"), .warning)
            .findings
    }
}

extension Lint.Rule.`literal conformance shadows validating init Tests`.Unit {
    @Test
    func `literal conformance alongside a throwing string protocol initializer is flagged`() {
        let findings = Lint.Rule.`literal conformance shadows validating init Tests`.findings(
            in: """
                struct Value: ExpressibleByStringLiteral {
                    init(_ value: some StringProtocol) throws {}
                }
                """
        )
        #expect(findings.count == 1)
        #expect(findings.first?.severity == .warning)
        #expect(findings.first?.message == idiomLiteralConformanceShadowsValidatingInitMessage)
    }

    @Test
    func `each half of the predicate alone is lawful`() {
        let findings = Lint.Rule.`literal conformance shadows validating init Tests`.findings(
            in: """
                struct Validated {
                    init(_ value: some StringProtocol) throws {}
                }
                struct Literal: ExpressibleByStringLiteral {
                    init(_ value: some StringProtocol) {}
                }
                """
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`literal conformance shadows validating init Tests`.`Edge Case` {
    @Test
    func `qualified conformance and typed initializer in separate extensions still fire`() {
        let findings = Lint.Rule.`literal conformance shadows validating init Tests`.findings(
            in: """
                struct Value {}
                extension Value: Swift.ExpressibleByStringLiteral {}
                extension Value {
                    init(_ value: some Swift.StringProtocol) throws(Value.Error) {}
                }
                """
        )
        #expect(findings.count == 1)
    }
}
