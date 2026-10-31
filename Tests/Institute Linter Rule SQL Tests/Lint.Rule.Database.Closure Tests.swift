import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_SQL

@Suite
struct `database closure type Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `database closure type Tests` {
    static func findings(_ source: Swift::String, file: Swift::String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        Lint.Rule.`database closure type`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
    }
}

extension `database closure type Tests`.Unit {
    @Test
    func `an untyped read that returns from two places fires`() {
        let findings = `database closure type Tests`.findings(
            """
            let keys = try database.read { db in
              if let pattern { return try Text.keys(matching: pattern).fetchAll(db) }
              return try Text.keys.fetchAll(db)
            }
            """
        )
        #expect(findings.count == 1)
        #expect(findings.first?.identifier == "database closure type")
        #expect("\(findings.first?.location.line, default: "")" == "1")
    }

    @Test
    func `every edge fires`() {
        for edge in ["read", "write", "writeWithoutTransaction", "withRollback", "observe"] {
            let findings = `database closure type Tests`.findings(
                """
                let value = try database.\(edge) { db in
                  let count = try Item.count.fetchOne(db)
                  return count
                }
                """
            )
            #expect(findings.count == 1, "\(edge)")
        }
    }

    @Test
    func `a stated result type does not fire`() {
        #expect(
            `database closure type Tests`.findings(
                """
                let keys = try database.read { (db: SQLite.Connection) throws -> [Int] in
                  if let pattern { return try Text.keys(matching: pattern).fetchAll(db) }
                  return try Text.keys.fetchAll(db)
                }
                let rows = try database.read { db -> [Int] in
                  let all = try Text.keys.fetchAll(db)
                  return all
                }
                """
            ).isEmpty
        )
    }

    @Test
    func `a single expression does not fire`() {
        #expect(`database closure type Tests`.findings("let n = try database.read { db in try Item.count.fetchOne(db) }").isEmpty)
    }

    @Test
    func `a single return statement does not fire`() {
        #expect(
            `database closure type Tests`.findings(
                """
                let n = try database.read { db in
                  return try Item.count.fetchOne(db)
                }
                """
            ).isEmpty
        )
    }

    @Test
    func `the edges are sql edge's`() {
        for edge in Lint.SQL.Edge.edges {
            let findings = `database closure type Tests`.findings(
                "let v = try database.\(edge) { db in\n  let n = try Item.count.fetchOne(db)\n  return n\n}"
            )
            #expect(findings.count == 1, "\(edge)")
        }
    }

    @Test
    func `a closure that returns nothing does not fire`() {
        #expect(
            `database closure type Tests`.findings(
                """
                try database.write { db in
                  try Item.delete().execute(db)
                  try Item.insert { Item(id: 1) }.execute(db)
                }
                """
            ).isEmpty
        )
    }
}

extension `database closure type Tests`.`Edge Case` {
    @Test
    func `a return in a nested closure is the nested closure's`() {
        #expect(
            `database closure type Tests`.findings(
                """
                try database.write { db in
                  let names = items.map { item in
                    let name = item.name
                    return name
                  }
                  try Item.save(names).execute(db)
                }
                """
            ).isEmpty
        )
    }

    @Test
    func `a nested database closure is checked on its own`() {
        let findings = `database closure type Tests`.findings(
            """
            try database.write { db in
              let rows = try other.read { db in
                let rows = try Item.all.fetchAll(db)
                return rows
              }
              try Item.save(rows).execute(db)
            }
            """
        )
        #expect(findings.count == 1)
        #expect("\(findings.first?.location.line, default: "")" == "2")
    }

    @Test
    func `near miss: another method with a closure does not fire`() {
        #expect(
            `database closure type Tests`.findings(
                """
                let value = cache.load { key in
                  let entry = entries[key]
                  return entry
                }
                """
            ).isEmpty
        )
    }

    @Test
    func `a closure argument, not trailing, fires`() {
        let findings = `database closure type Tests`.findings(
            """
            let value = try database.read({ db in
              let count = try Item.count.fetchOne(db)
              return count
            })
            """
        )
        #expect(findings.count == 1)
    }

    @Test
    func `a test target is checked too`() {
        let findings = `database closure type Tests`.findings(
            """
            let value = try database.read { db in
              let count = try Item.count.fetchOne(db)
              return count
            }
            """,
            file: "Tests/Affairs Tests/Store.Tests.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `bare filename still fires`() {
        let findings = `database closure type Tests`.findings(
            """
            let value = try database.read { db in
              let count = try Item.count.fetchOne(db)
              return count
            }
            """,
            file: "Test.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `message states what it checks and the fix`() {
        let message =
            `database closure type Tests`.findings(
                """
                let value = try database.read { db in
                  let count = try Item.count.fetchOne(db)
                  return count
                }
                """
            ).first?.message ?? ""
        #expect(message.contains("checks every closure passed to `read`"))
        #expect(message.contains("Fix:"))
        #expect(message.contains("swift-institute/Issues#181"))
    }
}

extension `database closure type Tests`.Integration {
    @Test
    func `controls hold`() {
        let outcomes = Lint.Rule.`database closure type`.outcomes()
        #expect(!outcomes.isEmpty)
        #expect(outcomes.contains { $0.expected > 0 })
        for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
    }
}
