import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Try

extension Lint.Rule {
    @Suite
    struct `unchecked try outside tests Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`unchecked try outside tests Tests` {
    static func findings(
        _ source: Swift::String,
        file: Swift::String = "Sources/Fixture/Fixture.swift"
    ) -> [Diagnostic.Record] {
        Lint.Rule.`unchecked try outside tests`
            .observe(Lint.Source.parsed(from: source, file: file), .warning)
            .findings
    }
}

extension Lint.Rule.`unchecked try outside tests Tests`.Unit {
    @Test
    func `forced try in sources is flagged`() {
        let findings = Lint.Rule.`unchecked try outside tests Tests`.findings(
            "func f() { let value = try! load() }"
        )
        #expect(findings.count == 1)
        #expect(findings[0].message.hasPrefix("[unchecked try outside tests] [SOURCE-UNCHECKED-TRY]:"))
    }

    @Test
    func `propagating and optional try are clean`() {
        let findings = Lint.Rule.`unchecked try outside tests Tests`.findings(
            "func f() throws { let a = try load(); let b = try? load() }"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`unchecked try outside tests Tests`.`Edge Case` {
    @Test
    func `forced try in tests is admitted`() {
        let findings = Lint.Rule.`unchecked try outside tests Tests`.findings(
            "func f() { let value = try! load() }",
            file: "Tests/Fixture Tests/Fixture Tests.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `nested forced tries are each flagged`() {
        let findings = Lint.Rule.`unchecked try outside tests Tests`.findings(
            "func f() { let value = try! load(try! key()) }",
            file: "/workspace/swift-fixture/Sources/Fixture/Fixture.swift"
        )
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`unchecked try outside tests Tests`.Integration {
    @Test
    func `forced try in an executable target is flagged`() {
        let findings = Lint.Rule.`unchecked try outside tests Tests`.findings(
            "@main enum Tool { static func main() { try! run() } }",
            file: "Sources/Fixture CLI/Tool.swift"
        )
        #expect(findings.count == 1)
    }
}
