import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_SQL

@Suite
struct `sql edge Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Exemption {}
    @Suite struct Integration {}
}

extension `sql edge Tests` {
    static func findings(
        _ source: Swift::String,
        file: Swift::String = "Sources/Affairs SQLite/Letter+SQLite.swift"
    ) -> [Diagnostic.Record] {
        Lint.Rule.`sql edge`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
    }
}

extension `sql edge Tests`.Unit {
    @Test(arguments: ["fetchAll", "fetchOne", "fetchCount", "fetchSet", "fetchCursor", "execute"])
    func `each execution call in a query function fires`(call: Swift::String) {
        let findings = `sql edge Tests`.findings(
            """
            extension Letter {
              static func pending(_ db: SQLite.Connection) throws {
                _ = try Letter.where(\\.isPending).\(call)(db)
              }
            }
            """
        )
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("`Letter.pending(_:)`") == true)
    }

    @Test
    func `a stored connection does not make a method an edge`() {
        let findings = `sql edge Tests`.findings(
            """
            struct Storage {
              let database: SQLite.Connection
              func history() throws -> [Row] { try Row.all.fetchAll(database) }
            }
            """
        )
        #expect(findings.count == 1)
    }

    @Test
    func `read and write closures are edges`() {
        let findings = `sql edge Tests`.findings(
            """
            extension Library {
              static func sqlite(_ database: SQLite.Database) -> Self {
                Self(
                  list: { try await database.read { db in try Letter.pending.fetchAll(db) } },
                  mark: { id in try await database.write { try Mark.insertion(id).execute($0) } },
                  raw: { try database.writeWithoutTransaction { db in try Letter.deletion.execute(db) } }
                )
              }
            }
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a fetch key request is an edge`() {
        let findings = `sql edge Tests`.findings(
            """
            struct Request: FetchKeyRequest {
              func fetch(_ db: SQLite.Connection) throws -> [Letter] { try Letter.all.fetchAll(db) }
            }
            extension Other: SQLite.FetchKeyRequest {
              func fetch(_ db: SQLite.Connection) throws -> Int { try Letter.all.fetchCount(db) }
            }
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `message names the declaration and the fix`() {
        let message = `sql edge Tests`.findings("func f(db: C) { try? T.all.execute(db) }").first?.message ?? ""
        #expect(message.contains("`f(db:)`"))
        #expect(message.contains("Fix:"))
    }
}

extension `sql edge Tests`.Unit {
    @Test
    func `a transaction's run is an edge`() {
        let findings = `sql edge Tests`.findings(
            """
            struct Derivation: SQLite.Transaction {
              func run(_ db: SQLite.Connection) throws { try Letter.Record.deletion.execute(db) }
            }
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `run that is not a transaction's is not an edge`() {
        let findings = `sql edge Tests`.findings(
            """
            struct Derivation: FetchKeyRequest {
              func run(_ db: SQLite.Connection) throws { try Letter.Record.deletion.execute(db) }
            }
            """
        )
        #expect(findings.count == 1)
    }

    @Test(arguments: [
        "try Letter.Record.where { $0.isPending }.fetchAll(db)",
        "try Letter.Record.insert { letter }.execute(db)",
        "try Letter.Record.order(by: \\.received).select(\\.id).fetchAll(db)",
        "try Letter.Record.find(id).update { $0.read = true }.execute(db)",
    ])
    func `a statement built at an edge fires`(call: Swift::String) {
        let findings = `sql edge Tests`.findings(
            "func load(_ database: SQLite.Database) throws { try database.write { db in \(call) } }"
        )
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("built here") == true)
    }

    @Test(arguments: [
        "try Letter.Record.pending.fetchAll(db)",
        "try Letter.Record.find(id).fetchOne(db)",
        "try Letter.Record.all.fetchAll(db)",
        "try Library.listed(query).fetchAll(db)",
    ])
    func `a named statement at an edge is clean`(call: Swift::String) {
        let findings = `sql edge Tests`.findings(
            "func load(_ database: SQLite.Database) throws { try database.read { db in \(call) } }"
        )
        #expect(findings.isEmpty)
    }
}

extension `sql edge Tests`.`Edge Case` {
    @Test
    func `a function declared inside a read closure is still at the edge`() {
        let findings = `sql edge Tests`.findings(
            """
            func load(_ database: SQLite.Database) async throws -> Int {
              try await database.read { db in
                func count() throws -> Int { try Letter.all.fetchCount(db) }
                return try count()
              }
            }
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a closure passed to another call is not an edge`() {
        let findings = `sql edge Tests`.findings(
            """
            func load(_ db: SQLite.Connection) throws -> [Int] {
              try ids.map { try Letter.find($0).fetchOne(db) }
            }
            """
        )
        #expect(findings.count == 1)
    }

    @Test
    func `fetch that is not a request's is not an edge`() {
        let findings = `sql edge Tests`.findings(
            """
            struct Listing {
              static func fetch(_ db: SQLite.Connection) throws -> [Letter] { try Letter.all.fetchAll(db) }
            }
            """
        )
        #expect(findings.count == 1)
    }

    @Test
    func `free function calls named like executions do not fire`() {
        #expect(`sql edge Tests`.findings("func f() { execute(plan) }").isEmpty)
    }

    @Test(arguments: [
        "process.execute()",
        "executor.execute(job)",
        "self.executor.execute(job)",
        "queue.execute(job, priority: .high)",
    ])
    func `an execute that runs no SQL does not fire`(call: Swift::String) {
        #expect(`sql edge Tests`.findings("func f(_ db: SQLite.Connection) throws { try \(call) }").isEmpty)
    }

    @Test(arguments: [
        "try Letter.all.execute(db)",
        "try X.statement.execute(db)",
        "try statement.execute(db)",
        "try deletion.execute(connection)",
        "try Item.fetchAll(db, sql: text)",
    ])
    func `an execution of a statement or on a connection fires`(call: Swift::String) {
        #expect(`sql edge Tests`.findings("func f(_ db: SQLite.Connection) throws { \(call) }").count == 1)
    }

    @Test
    func `the message promises only the edges the rule exempts`() {
        let message = `sql edge Tests`.findings("func f(db: C) { try? T.all.execute(db) }").first?.message ?? ""
        #expect(!message.contains("reducer"))
        #expect(message.contains("Transaction"))
    }
}

extension `sql edge Tests`.Exemption {
    @Test(arguments: [
        "Sources/Affairs Schema/Schema+Sync.swift",
        "Tests/Affairs Tests/Letter.Tests.swift",
        "Hosts/Laurie/App.swift",
    ])
    func `schema targets, tests and hosts are inapplicable`(file: Swift::String) {
        let observation = Lint.Rule.`sql edge`.observe(
            Lint.Source.parsed(from: "func f(_ db: C) throws { try T.all.execute(db) }", file: file),
            .warning
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }

    @Test
    func `an executable target is an edge`() throws {
        let fixture = try Lint.Source.Fixture(files: [
            "Sources/db/main.swift": "print(1)",
            "Sources/db/Command.swift": "func run(_ db: C) throws { try T.all.execute(db) }",
        ])
        let observation = Lint.Rule.`sql edge`.observe(fixture.parsed("Sources/db/Command.swift"), .warning)
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }

    @Test(arguments: [
        "Letter.swift",
        "Library/Letter.swift",
        "Sources/Affairs/Tests/Letter.swift",
        "Sources/Affairs/Hosts/Letter.swift",
        "TestsKit/Letter.swift",
        "Sources/Schema/Letter.swift",
        "Sources/Affairs Schemas/Letter.swift",
    ])
    func `near miss: every other path fires, a bare filename too`(file: Swift::String) {
        let findings = `sql edge Tests`.findings("func f(_ db: C) throws { try T.all.execute(db) }", file: file)
        #expect(findings.count == 1, "\(file)")
    }
}

extension `sql edge Tests`.Integration {
    @Test
    func `controls hold`() {
        let outcomes = Lint.Rule.`sql edge`.outcomes()
        #expect(outcomes.contains { $0.expected > 0 })
        for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
    }
}
