import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_SQL

@Suite
struct `sql fragment Tests` {
    @Suite struct Unit {}
    @Suite struct Exemption {}
    @Suite struct Integration {}
}

extension `sql fragment Tests` {
    static func findings(
        _ source: Swift::String,
        file: Swift::String = "Sources/Affairs SQLite/Library+SQLite.swift"
    ) -> [Diagnostic.Record] {
        Lint.Rule.`sql fragment`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
    }
}

extension `sql fragment Tests`.Unit {
    @Test(arguments: [
        #"let a = #sql("SELECT count(*) FROM \(Item.self)", as: Int.self)"#,
        #"let b = #sql("DELETE FROM \(Item.self)")"#,
        #"let c = #sql("PRAGMA quick_check", as: String.self)"#,
        "let d = #sql(\n  \"\"\"\n  WITH \\(Library.letters)\n  SELECT 1\n  \"\"\"\n)",
    ])
    func `whole statements fire`(source: Swift::String) {
        let findings = `sql fragment Tests`.findings(source)
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("whole statement") == true)
    }

    @Test(arguments: [
        ##"let a = #sql(#""listed"."flagged""#, as: Bool.self)"##,
        #"let b = #sql("\"date\" IS NULL, \(Item.columns.id)")"#,
        "let c = #sql(\n  \"\"\"\n  coalesce(\"listed\".\"person\", '') || \\(x)\n  \"\"\"\n)",
    ])
    func `quoted identifiers fire`(source: Swift::String) {
        let findings = `sql fragment Tests`.findings(source)
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("quoted identifier") == true)
    }

    @Test
    func `a fragment without interpolation fires`() {
        let findings = `sql fragment Tests`.findings(#"let all = #sql("1", as: Bool.self)"#)
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("interpolates nothing") == true)
    }

    @Test(arguments: [
        #"let a = #sql("harvest_matches(\(Listed.columns.text), \(search))", as: Bool.self)"#,
        #"let b = #sql("\(Letter.columns.date) IS NULL", as: Bool.self)"#,
        #"let c = #sql("strftime('%Y', \(Letter.columns.date))", as: String.self)"#,
    ])
    func `interpolated fragments are clean`(source: Swift::String) {
        #expect(`sql fragment Tests`.findings(source).isEmpty)
    }
}

extension `sql fragment Tests`.Exemption {
    @Test
    func `schema target is inapplicable`() {
        let observation = Lint.Rule.`sql fragment`.observe(
            Lint.Source.parsed(from: #"let v = #sql("CREATE TABLE t (id)")"#, file: "Sources/Affairs Schema/V1.swift"),
            .warning
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }

    @Test
    func `a test target is inapplicable`() {
        let observation = Lint.Rule.`sql fragment`.observe(
            Lint.Source.parsed(from: #"let v = #sql("DELETE FROM \(Item.self)")"#, file: "Tests/Affairs Tests/Store.Tests.swift"),
            .warning
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }

    @Test(arguments: [
        "Library.swift",
        "Sources/Affairs/Tests/Library.swift",
        "Sources/Schema/V1.swift",
        "Sources/Affairs Schemas/V1.swift",
        "TestsKit/Library.swift",
    ])
    func `near miss: every other path fires, a bare filename too`(file: Swift::String) {
        let findings = `sql fragment Tests`.findings(#"let v = #sql("DELETE FROM \(Item.self)")"#, file: file)
        #expect(findings.count == 1, "\(file)")
    }
}

extension `sql fragment Tests`.Integration {
    @Test
    func `controls hold`() {
        let outcomes = Lint.Rule.`sql fragment`.outcomes()
        #expect(outcomes.contains { $0.expected > 0 })
        for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
    }
}
