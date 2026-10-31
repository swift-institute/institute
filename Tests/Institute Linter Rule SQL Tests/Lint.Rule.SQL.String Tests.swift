import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_SQL

@Suite
struct `sql string Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Exemption {}
    @Suite struct Integration {}
}

extension `sql string Tests` {
    static func findings(_ source: Swift::String, file: Swift::String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        Lint.Rule.`sql string`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
    }
}

extension `sql string Tests`.Unit {
    @Test(arguments: [
        "SELECT name FROM holder",
        "  SELECT count(*) FROM item WHERE flag = 1",
        "INSERT INTO item VALUES (1)",
        "INSERT OR REPLACE INTO item VALUES (1)",
        "REPLACE INTO item VALUES (1)",
        "UPDATE item SET flag = 1",
        "DELETE FROM item",
        "CREATE TABLE item (id INTEGER)",
        "CREATE UNIQUE INDEX item_id ON item (id)",
        "CREATE TEMP TRIGGER t AFTER INSERT ON item BEGIN SELECT 1; END",
        "CREATE VIEW v AS SELECT id FROM item",
        "ALTER TABLE item ADD COLUMN flag",
        "DROP TABLE item",
        "DROP INDEX item_id",
        "PRAGMA foreign_keys = ON",
        "WITH recent AS (SELECT id FROM item) SELECT id FROM recent",
        "BEGIN TRANSACTION",
        "BEGIN IMMEDIATE",
    ])
    func `every upper-case statement shape fires`(statement: Swift::String) {
        #expect(`sql string Tests`.findings("let s = \"\(statement)\"").count == 1, "\(statement)")
    }

    @Test
    func `a bare upper-case keyword does not fire`() {
        let findings = `sql string Tests`.findings(
            """
            request.httpMethod = "DELETE"
            let a = "UPDATE"
            let b = "SELECT ALL"
            let c = "PRAGMA"
            let d = "BEGIN"
            let e = "DROP x"
            let f = "INSERT x"
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `prose and lower-case text do not fire`() {
        let findings = `sql string Tests`.findings(
            """
            let a = "Delete from library"
            let b = "Select documents from the list"
            let c = "Update the record, then set it aside"
            let d = "select name from holder"
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `prose beginning with a keyword word does not fire`() {
        let findings = `sql string Tests`.findings(
            """
            let a = "Select Documents"
            let b = "With SMS"
            let c = "Select documents before refreshing local readings."
            let d = "Delete"
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `keyword not at the start does not fire`() {
        let findings = `sql string Tests`.findings(
            """
            let a = "Run SELECT later"
            let b = "(SELECT 1)"
            let c = "SELECTED"
            """
        )
        #expect(findings.isEmpty)
    }
}

extension `sql string Tests`.`Edge Case` {
    @Test
    func `multi-line and raw literals fire`() {
        let findings = `sql string Tests`.findings(
            """
            let a = \"\"\"

                SELECT "id"
                FROM "item"
                \"\"\"
            let b = #"INSERT INTO "item"("id") VALUES (?)"#
            """
        )
        #expect(findings.count == 2)
    }

    @Test
    func `interpolated literal with a leading keyword fires`() {
        #expect(`sql string Tests`.findings(#"let s = "SELECT count(*) FROM \(table)""#).count == 1)
    }

    @Test
    func `literal nested in a sql macro interpolation still fires`() {
        let findings = `sql string Tests`.findings(
            #"let s = #sql("x IN (\(raw("SELECT id FROM item")))")"#
        )
        #expect(findings.count == 1)
    }

    @Test
    func `bare filename still fires`() {
        #expect(`sql string Tests`.findings("let s = \"DROP TABLE x\"", file: "Test.swift").count == 1)
    }
}

extension `sql string Tests`.Exemption {
    @Test
    func `direct argument of sql macro is exempt`() {
        let findings = `sql string Tests`.findings(
            """
            let a = #sql("SELECT holderID FROM retrievalJoin", as: String.self)
            let b = #sql(#"PRAGMA quick_check"#)
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `near miss: argument of another macro still fires`() {
        #expect(`sql string Tests`.findings(#"let a = #query("SELECT id FROM item")"#).count == 1)
    }

    @Test
    func `a test target is inapplicable`() {
        let observation = Lint.Rule.`sql string`.observe(
            Lint.Source.parsed(from: "let s = \"DELETE FROM item\"", file: "Tests/Affairs Tests/Store.Tests.swift"),
            .warning
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }

    @Test
    func `near miss: a Tests directory inside a source target still fires`() {
        #expect(`sql string Tests`.findings("let s = \"DELETE FROM item\"", file: "Sources/X/Tests/a.swift").count == 1)
    }
}

extension `sql string Tests`.Integration {
    @Test
    func `controls hold`() {
        let outcomes = Lint.Rule.`sql string`.outcomes()
        #expect(outcomes.contains { $0.expected > 0 })
        for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
    }
}
