import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_SQL

@Suite
struct `sql label Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `sql label Tests` {
    static func findings(_ source: Swift::String, file: Swift::String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        Lint.Rule.`sql label`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
    }
}

extension `sql label Tests`.Unit {
    @Test
    func `call argument labelled sql fires`() {
        let findings = `sql label Tests`.findings(
            """
            func run() throws {
              try db.execute(sql: "DELETE FROM item")
              let n = try Int.fetchOne(db, sql: statement)
            }
            """
        )
        #expect(findings.count == 2)
        #expect(findings.first?.identifier == "sql label")
        #expect("\(findings.first?.location.line, default: "")" == "2")
    }

    @Test
    func `parameter declaration labelled sql does not fire`() {
        #expect(`sql label Tests`.findings("func execute(sql: String) {}").isEmpty)
    }

    @Test
    func `other labels do not fire`() {
        #expect(`sql label Tests`.findings("run(sqlText: x, query: y)").isEmpty)
    }
}

extension `sql label Tests`.`Edge Case` {
    @Test
    func `subscript and macro arguments fire`() {
        let findings = `sql label Tests`.findings(
            """
            let a = cache[sql: key]
            let b = #statement(sql: text)
            """
        )
        #expect(findings.count == 2)
    }

    @Test
    func `tuple element labelled sql does not fire`() {
        #expect(`sql label Tests`.findings("let pair = (sql: 1, other: 2)").isEmpty)
    }

    @Test
    func `a test target is exempt`() {
        #expect(`sql label Tests`.findings("run(sql: x)", file: "Tests/Affairs Tests/Store.Tests.swift").isEmpty)
    }

    @Test
    func `bare filename still fires`() {
        #expect(`sql label Tests`.findings("run(sql: x)", file: "Test.swift").count == 1)
    }

    @Test(arguments: ["Sources/X/Tests/a.swift", "TestsKit/a.swift", "Sources/Tests/a.swift"])
    func `near miss: a Tests segment that is not the first directory still fires`(file: Swift::String) {
        #expect(`sql label Tests`.findings("run(sql: x)", file: file).count == 1, "\(file)")
    }

    @Test
    func `message states what it checks and the fix`() {
        let message = `sql label Tests`.findings("run(sql: x)").first?.message ?? ""
        #expect(message.contains("checks every call argument labelled `sql:`"))
        #expect(message.contains("Fix:"))
    }

    @Test
    func `message names no exception list it does not consult`() {
        let message = `sql label Tests`.findings("run(sql: x)").first?.message ?? ""
        #expect(!message.contains("Lint.SQL.Exceptions"))
        #expect(message.contains("no exemption list"))
    }
}

extension `sql label Tests`.Integration {
    @Test
    func `controls hold`() {
        let outcomes = Lint.Rule.`sql label`.outcomes()
        #expect(!outcomes.isEmpty)
        #expect(outcomes.contains { $0.expected > 0 })
        for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
    }
}
