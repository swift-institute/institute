public import Lint
internal import Linter_Rule_Scope
internal import SwiftSyntax

extension Lint.Rule {

    public static let `sql fragment` = Lint.Rule(
        id: "sql fragment",
        default: .warning,
        controls: [
            .init(
                id: "sql fragment whole statement",
                source: """
                    let latest = #sql("SELECT max(\\(Update.columns.day)) FROM \\(Update.self)", as: String?.self)
                    """,
                path: "Sources/Controls SQLite/Latest.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "sql fragment quoted identifier",
                source: """
                    let flagged = #sql(#""listed"."flagged""#, as: Bool.self)
                    """,
                path: "Sources/Controls SQLite/Flagged.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "sql fragment interpolated columns",
                source: """
                    let matches = #sql("harvest_matches(\\(Listed.columns.text), \\(search))", as: Bool.self)
                    """,
                path: "Sources/Controls SQLite/Matches.swift",
                expectation: .clean
            ),
            .init(
                id: "sql fragment schema target",
                source: """
                    let v1 = #sql("CREATE TABLE item (id INTEGER PRIMARY KEY)")
                    """,
                path: "Sources/Controls Schema/V1.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
        ],
        observe: { source, severity in
            Lint.SQL.Fragment.observe(source, severity: severity)
        }
    )
}
