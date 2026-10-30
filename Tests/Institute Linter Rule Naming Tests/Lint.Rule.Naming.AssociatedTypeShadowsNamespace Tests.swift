import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Naming

extension Lint.Rule {
    @Suite
    struct `associated type shadows namespace Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`associated type shadows namespace Tests` {
    static func findings(_ source: Swift::String) -> [Diagnostic.Record] {
        Lint.Rule.`associated type shadows namespace`
            .observe(Lint.Source.parsed(from: source, file: "Sources/Fixture/Fixture.swift"), .warning)
            .findings
    }
}

extension Lint.Rule.`associated type shadows namespace Tests`.Unit {
    @Test
    func `associated type matching the enclosing namespace is flagged`() {
        let findings = Lint.Rule.`associated type shadows namespace Tests`.findings(
            "extension Coder { protocol Codable { associatedtype Coder } }"
        )
        #expect(findings.count == 1)
        #expect(findings.first?.identifier == "associated type shadows namespace")
        #expect(findings.first?.severity == .warning)
        #expect(
            findings.first?.message
                == "[associated type shadows namespace]: an associated type or nested type declared "
                + "directly in a protocol or extension has the same name as its enclosing namespace "
                + "root; use a top-level protocol typealias at conformance sites so the nested name "
                + "does not shadow the namespace."
        )
    }

    @Test
    func `top-level protocol typealias is lawful`() {
        let findings = Lint.Rule.`associated type shadows namespace Tests`.findings(
            "public typealias Coding = Coder.Protocol"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`associated type shadows namespace Tests`.`Edge Case` {
    @Test
    func `nested nominal type in qualified extension still fires`() {
        let findings = Lint.Rule.`associated type shadows namespace Tests`.findings(
            "extension Coder.Codable { struct Coder {} }"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `different associated type name is lawful`() {
        let findings = Lint.Rule.`associated type shadows namespace Tests`.findings(
            "extension Coder { protocol Codable { associatedtype Value } }"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `same name inside an ordinary nested type is outside the predicate`() {
        let findings = Lint.Rule.`associated type shadows namespace Tests`.findings(
            "extension Coder { struct Container { struct Coder {} } }"
        )
        #expect(findings.isEmpty)
    }
}
