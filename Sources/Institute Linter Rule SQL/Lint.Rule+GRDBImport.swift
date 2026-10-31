public import Lint
internal import Linter_Rule_Scope
internal import SwiftSyntax

extension Lint.Rule {

    /// Enabled everywhere except swift-sqlite, the only package that may drive GRDB.
    public static let `grdb import` = Lint.Rule(
        id: "grdb import",
        default: .warning,
        controls: [
            .init(
                id: "grdb import in a domain target",
                source: """
                    public import GRDB
                    import SQLite
                    """,
                path: "Sources/Controls SQLite/Store.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "grdb import manifest dependency",
                source: """
                    let package = Package(
                      name: "Controls",
                      dependencies: [.package(url: "https://github.com/groue/GRDB.swift", from: "7.6.0")]
                    )
                    """,
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "grdb import versioned manifest dependency",
                source: """
                    let package = Package(dependencies: [.package(url: "https://github.com/groue/GRDB.swift", from: "7.6.0")])
                    """,
                path: "Package@swift-6.0.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "grdb import file named like a manifest",
                source: """
                    let package = Package(dependencies: [.package(url: "https://github.com/groue/GRDB.swift", from: "7.6.0")])
                    """,
                path: "MyPackage.swift",
                expectation: .clean
            ),
            .init(
                id: "grdb import swift-sqlite",
                source: """
                    import SQLite
                    import SQL
                    """,
                path: "Sources/Controls SQLite/Store.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = GRDBImportVisitor(manifest: Lint.Scope.File.isManifest(source.path))
            visitor.walk(source.tree)
            return visitor.sites.map { site in
                Lint.Scope.record(
                    at: site,
                    in: source,
                    severity: severity,
                    identifier: "grdb import",
                    message: `grdb import message`
                )
            }
        }
    )
}

package let `grdb import message`: Swift::String =
    "[grdb import]: checks every `import GRDB` (any access level, `@_exported`, or of a single "
    + "declaration) and every manifest string naming the GRDB.swift package. GRDB is swift-sqlite's "
    + "private driver; a consumer that imports it can bypass swift-sql's typed statements and "
    + "swift-sqlite's database. Fix: use `SQLite.Database`, `SQLite.Connection` and swift-sql "
    + "statements, and add to swift-sqlite what is missing there."

internal final class GRDBImportVisitor: SyntaxVisitor {
    let manifest: Swift::Bool
    var sites: [Syntax] = []

    init(manifest: Swift::Bool) {
        self.manifest = manifest
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.path.first?.name.text == "GRDB" { sites.append(Syntax(node)) }
        return .skipChildren
    }

    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        guard manifest else { return .skipChildren }
        let text = Lint.SQL.Statement.text(of: node)
        if text == "GRDB.swift" || text.hasSuffix("/GRDB.swift") || text.hasSuffix("/GRDB.swift.git") {
            sites.append(Syntax(node))
        }
        return .skipChildren
    }
}
