import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Idiom

extension Lint.Rule {
    @Suite
    struct `fatal error outside tests Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`fatal error outside tests Tests` {
    static func findings(
        _ source: Swift::String,
        file: Swift::String = "Sources/Fixture/Fixture.swift"
    ) -> [Diagnostic.Record] {
        Lint.Rule.`fatal error outside tests`
            .observe(Lint.Source.parsed(from: source, file: file), .warning)
            .findings
    }
}

extension Lint.Rule.`fatal error outside tests Tests`.Unit {
    @Test
    func `fatal error in sources is flagged`() {
        let findings = Lint.Rule.`fatal error outside tests Tests`.findings(
            "func f() -> Never { fatalError(\"unreachable\") }"
        )
        #expect(findings.count == 1)
        #expect(findings[0].message.hasPrefix("[fatal error outside tests] [SOURCE-FATAL-ERROR]:"))
    }

    @Test
    func `module-qualified fatal error is flagged`() {
        let findings = Lint.Rule.`fatal error outside tests Tests`.findings(
            "func f() -> Never { Swift.fatalError() }"
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`fatal error outside tests Tests`.`Edge Case` {
    @Test
    func `fatal error in tests is admitted`() {
        let findings = Lint.Rule.`fatal error outside tests Tests`.findings(
            "func f() -> Never { fatalError() }",
            file: "Tests/Fixture Tests/Fixture Tests.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a member named fatalError is not the trap`() {
        let findings = Lint.Rule.`fatal error outside tests Tests`.findings(
            "func f() { logger.fatalError(\"message\") }"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`fatal error outside tests Tests`.Integration {
    @Test
    func `fatal error in an absolute source path is flagged`() {
        let findings = Lint.Rule.`fatal error outside tests Tests`.findings(
            "func f() -> Never { fatalError() }",
            file: "/workspace/swift-fixture/Sources/Fixture/Fixture.swift"
        )
        #expect(findings.count == 1)
    }
}
