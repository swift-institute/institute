public import Lint
internal import Linter_Rule_Scope
internal import SwiftSyntax

extension Lint.Rule {

    public static func `sql registry`(exceptions: Lint.SQL.Exceptions) -> Lint.Rule {
        Lint.Rule(
            id: "sql registry",
            default: .warning,
            controls: [
                .init(
                    id: "sql registry unlisted site",
                    source: """
                        extension Library {
                          func pending() -> SQLQueryExpression<Bool> { #sql("\\"pending\\"") }
                        }
                        """,
                    path: "Sources/Controls/SQLRegistry.swift",
                    expectation: .findings(1)
                ),
                .init(
                    id: "sql registry schema target",
                    source: """
                        enum Version1 {
                          static let table = #sql("CREATE TABLE item (id INTEGER PRIMARY KEY)")
                        }
                        """,
                    path: "Sources/Controls Schema/Version1.swift",
                    expectation: .clean,
                    applicability: .inapplicable
                ),
            ],
            observe: { source, severity in
                Lint.SQL.Registry(exceptions: exceptions).observe(source, severity: severity)
            }
        )
    }
}
