import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Idiom

extension `Lint.Rule Tests` {
    @Suite
    struct `fatal error outside tests Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension `Lint.Rule Tests`.`fatal error outside tests Tests` {
    static func findings(
        _ source: Swift::String,
        file: Swift::String = "Sources/Fixture/Fixture.swift"
    ) -> [Diagnostic.Record] {
        Lint.Rule.`fatal error outside tests`
            .observe(Lint.Source.parsed(from: source, file: file), .warning)
            .findings
    }
}

extension `Lint.Rule Tests`.`fatal error outside tests Tests`.Unit {
    @Test
    func `fatal error in sources is flagged`() {
        let findings = `Lint.Rule Tests`.`fatal error outside tests Tests`.findings(
            "func f() { fatalError(\"unreachable\") }"
        )
        #expect(findings.count == 1)
        #expect(findings[0].message.hasPrefix("[fatal error outside tests] [SOURCE-FATAL-ERROR]:"))
    }

    @Test
    func `module-qualified fatal error is flagged`() {
        let findings = `Lint.Rule Tests`.`fatal error outside tests Tests`.findings(
            "func f() { Swift.fatalError() }"
        )
        #expect(findings.count == 1)
    }
}

extension `Lint.Rule Tests`.`fatal error outside tests Tests`.`Edge Case` {
    @Test
    func `fatal error in tests is admitted`() {
        let findings = `Lint.Rule Tests`.`fatal error outside tests Tests`.findings(
            "func f() { fatalError() }",
            file: "Tests/Fixture Tests/Fixture Tests.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a member named fatalError is not the trap`() {
        let findings = `Lint.Rule Tests`.`fatal error outside tests Tests`.findings(
            "func f() { logger.fatalError(\"message\") }"
        )
        #expect(findings.isEmpty)
    }
}

extension `Lint.Rule Tests`.`fatal error outside tests Tests`.Integration {
    @Test
    func `fatal error in an absolute source path is flagged`() {
        let findings = `Lint.Rule Tests`.`fatal error outside tests Tests`.findings(
            "func f() { fatalError() }",
            file: "/workspace/swift-fixture/Sources/Fixture/Fixture.swift"
        )
        #expect(findings.count == 1)
    }
}

extension `Lint.Rule Tests` {
    /// swift-institute/Issues#271: a `fatalError` that is the only statement of the body of a function returning
    /// `Never`, or of a computed property or subscript of type `Never`, is that body's whole meaning (the type already
    /// says the body never returns) and is not counted. Every other `fatalError` is.
    @Suite struct `fatal error outside tests Never body Tests` {
        static func count(_ source: Swift::String) -> Swift::Int {
            `Lint.Rule Tests`.`fatal error outside tests Tests`.findings(source).count
        }
    }
}

extension `Lint.Rule Tests`.`fatal error outside tests Never body Tests` {
    @Test func `the only statement of a function returning Never is skipped`() {
        #expect(Self.count("func f() -> Never { fatalError(\"unreachable\") }") == 0)
    }

    @Test func `a returned fatal error in a function returning Swift Never is skipped`() {
        #expect(Self.count("func f() -> Swift.Never { return Swift.fatalError() }") == 0)
    }

    @Test func `the only statement of a method returning Never is skipped`() {
        #expect(Self.count("struct S { static func trap(_ message: String) -> Never { fatalError(message) } }") == 0)
    }

    @Test func `the only statement of a computed property of type Never is skipped`() {
        #expect(Self.count("struct Leaf: Rendering { var body: Never { fatalError() } }") == 0)
    }

    @Test func `the only statement of a borrowing getter of type Never is skipped`() {
        #expect(Self.count("struct Leaf { var body: Never { borrowing get { return fatalError(\"leaf\") } } }") == 0)
    }

    @Test func `the only statement of a subscript of type Never is skipped`() {
        #expect(Self.count("struct S { subscript(index: Int) -> Never { fatalError() } }") == 0)
    }

    @Test func `the only statement of a subscript getter of type Never is skipped`() {
        #expect(Self.count("struct S { subscript(index: Int) -> Never { get { fatalError() } } }") == 0)
    }

    @Test func `a function returning Never that does other work first is counted`() {
        #expect(Self.count("func f() -> Never { log(); fatalError() }") == 1)
    }

    @Test func `a property of type Never that does other work first is counted`() {
        #expect(Self.count("struct Leaf { var body: Never { log(); fatalError() } }") == 1)
    }

    @Test func `a fatal error under a branch of a function returning Never is counted`() {
        #expect(Self.count("func f(_ c: Bool) -> Never { if c { fatalError(\"a\") } else { fatalError(\"b\") } }") == 2)
    }

    @Test func `a fatal error in a closure inside a function returning Never is counted`() {
        #expect(Self.count("func f() -> Never { run { fatalError() } }") == 1)
    }

    @Test func `the only statement of a function returning something else is counted`() {
        #expect(Self.count("func f() -> Int { fatalError() }") == 1)
    }

    @Test func `the only statement of a function returning optional Never is counted`() {
        #expect(Self.count("func f() -> Never? { fatalError() }") == 1)
    }

    @Test func `the only statement of a function without a return type is counted`() {
        #expect(Self.count("func f() { fatalError() }") == 1)
    }

    @Test func `the only statement of a property of another type is counted`() {
        #expect(Self.count("struct Leaf { var body: Int { fatalError() } }") == 1)
    }

    @Test func `the only statement of a closure of type Never is counted`() {
        #expect(Self.count("let trap: () -> Never = { fatalError() }") == 1)
    }

    @Test func `the only statement of a setter of a Never property is counted`() {
        #expect(Self.count("struct S { var x: Never { get { fatalError() } set { fatalError() } } }") == 1)
    }
}
