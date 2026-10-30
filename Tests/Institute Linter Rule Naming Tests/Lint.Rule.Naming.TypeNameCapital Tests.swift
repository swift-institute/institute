import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Naming

extension Lint.Rule {
    @Suite
    struct `type name capital Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`type name capital Tests` {
    static func findings(
        _ source: Swift::String,
        file: Swift::String = "Sources/Fixture/Fixture.swift"
    ) -> [Diagnostic.Record] {
        Lint.Rule.`type name capital`
            .observe(Lint.Source.parsed(from: source, file: file), .warning)
            .findings
    }
}

extension Lint.Rule.`type name capital Tests`.Unit {
    @Test
    func `every lowercase nominal type is flagged`() {
        let findings = Lint.Rule.`type name capital Tests`.findings(
            "struct a {}\nenum b {}\nclass c {}\nactor d {}\nprotocol e {}"
        )
        #expect(findings.count == 5)
        #expect(findings.first?.message.hasPrefix("[type name capital]:") == true)
    }

    @Test
    func `uppercase nominal types are clean`() {
        #expect(Lint.Rule.`type name capital Tests`.findings("struct Value { enum Kind {} }").isEmpty)
    }

    @Test
    func `a nested lowercase type is flagged at its name`() {
        let findings = Lint.Rule.`type name capital Tests`.findings("extension Value {\n  struct helper {}\n}")
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`type name capital Tests`.`Edge Case` {
    @Test
    func `leading underscores are skipped before the first letter`() {
        #expect(Lint.Rule.`type name capital Tests`.findings("protocol __HashTable {}\nstruct _Box {}").isEmpty)
        #expect(Lint.Rule.`type name capital Tests`.findings("struct __box {}").count == 1)
    }

    @Test
    func `backticked names are judged without the backticks`() {
        #expect(Lint.Rule.`type name capital Tests`.findings("protocol `Protocol` {}\nstruct `Binary data` {}").isEmpty)
        #expect(Lint.Rule.`type name capital Tests`.findings("enum `default` {}").count == 1)
    }

    @Test
    func `specification section numerals are clean`() {
        #expect(Lint.Rule.`type name capital Tests`.findings("extension ISO_32000 { enum `10` {} }").isEmpty)
    }

    @Test
    func `typealiases and test sources are out of scope`() {
        #expect(Lint.Rule.`type name capital Tests`.findings("typealias circle = Circle").isEmpty)
        #expect(
            Lint.Rule.`type name capital Tests`.findings(
                "struct helper {}",
                file: "Tests/Fixture Tests/Fixture Tests.swift"
            ).isEmpty
        )
    }
}
