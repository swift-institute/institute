import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Naming

extension Lint.Rule {
    @Suite
    struct `ascii identifier Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`ascii identifier Tests` {
    static func findings(
        _ source: Swift::String,
        file: Swift::String = "Sources/Fixture/Fixture.swift"
    ) -> [Diagnostic.Record] {
        Lint.Rule.`ascii identifier`
            .observe(Lint.Source.parsed(from: source, file: file), .warning)
            .findings
    }
}

extension Lint.Rule.`ascii identifier Tests`.Unit {
    @Test
    func `non-ascii declared names are flagged`() {
        let findings = Lint.Rule.`ascii identifier Tests`.findings(
            """
            public struct Caf\u{00E9} {
                let na\u{00EF}ve = 1
                func r\u{00E9}sum\u{00E9}(\u{00FC}ber: Int) {}
            }
            enum Kind { case \u{00E9}t\u{00E9} }
            """
        )
        #expect(findings.count == 5)
        #expect(findings[0].message.hasPrefix("[ascii identifier] [SOURCE-ENGLISH-IDENTIFIER]:"))
    }

    @Test
    func `ascii names are clean`() {
        let findings = Lint.Rule.`ascii identifier Tests`.findings(
            "public struct Entity { let name = \"caf\u{00E9}\"; func `spaced name`() {} }"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`ascii identifier Tests`.`Edge Case` {
    @Test
    func `uses of a non-ascii name are not re-flagged`() {
        let findings = Lint.Rule.`ascii identifier Tests`.findings(
            "let value = Caf\u{00E9}()"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `tests are out of scope`() {
        let findings = Lint.Rule.`ascii identifier Tests`.findings(
            "struct Caf\u{00E9} {}",
            file: "Tests/Fixture Tests/Fixture Tests.swift"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`ascii identifier Tests`.Integration {
    @Test
    func `an absolute source path is in scope`() {
        let findings = Lint.Rule.`ascii identifier Tests`.findings(
            "typealias Stra\u{00DF}e = String",
            file: "/workspace/swift-fixture/Sources/Fixture/Fixture.swift"
        )
        #expect(findings.count == 1)
    }
}
