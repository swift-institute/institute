public import Lint
internal import Linter_Rule_Scope
internal import SwiftSyntax

extension Lint.Rule {

    public static let `sql edge` = Lint.Rule(
        id: "sql edge",
        default: .warning,
        controls: [
            .init(
                id: "sql edge fetch inside a query function",
                source: """
                    extension Letter {
                      static func pending(_ db: SQLite.Connection) throws -> [Letter] {
                        try Letter.where(\\.isPending).fetchAll(db)
                      }
                    }
                    """,
                path: "Sources/Controls SQLite/Letter.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "sql edge bare filename",
                source: """
                    func pending(_ db: SQLite.Connection) throws -> [Letter] { try Letter.pending.fetchAll(db) }
                    """,
                path: "Letter.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "sql edge execute that runs no statement",
                source: """
                    func run(_ db: SQLite.Connection) { process.execute(); executor.execute(job) }
                    """,
                path: "Sources/Controls SQLite/Run.swift",
                expectation: .clean
            ),
            .init(
                id: "sql edge fetch inside a read closure",
                source: """
                    extension Library {
                      static func sqlite(_ database: SQLite.Database) -> Self {
                        Self { try await database.read { db in try Letter.pending.fetchAll(db) } }
                      }
                    }
                    """,
                path: "Sources/Controls SQLite/Library.swift",
                expectation: .clean
            ),
            .init(
                id: "sql edge migration target",
                source: """
                    let v1 = Version { connection in try Schema.v1.execute(connection) }
                    """,
                path: "Sources/Controls Schema/V1.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
        ],
        observe: { source, severity in
            Lint.SQL.Edge.observe(source, severity: severity)
        }
    )
}
