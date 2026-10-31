public import Lint
internal import Linter_Rule_Scope
internal import SwiftSyntax

extension Lint.Rule {

    public static let `sql label` = Lint.Rule(
        id: "sql label",
        default: .warning,
        controls: [
            .init(
                id: "sql label argument",
                source: """
                    func count() throws -> Int? {
                      try Int.fetchOne(db, sql: "SELECT count(*) FROM item")
                    }
                    """,
                path: "Controls/SQLLabel.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "sql label parameter declaration",
                source: """
                    func execute(sql: Statement) {}
                    """,
                path: "Controls/SQLLabelDeclaration.swift",
                expectation: .clean
            ),
        ],
        observe: { source, severity in
            guard !Lint.Scope.Target.isTest(source.path) else {
                return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
            }
            let visitor = SQLLabelVisitor()
            visitor.walk(source.tree)
            let findings = visitor.labels.map { label in
                Lint.Scope.record(
                    at: label,
                    in: source,
                    severity: severity,
                    identifier: "sql label",
                    message: `sql label message`
                )
            }
            return Lint.Rule.Observation(findings: findings, coverage: .measured)
        }
    )
}

package let `sql label message`: Swift::String =
    "[sql label]: checks every call argument labelled `sql:` outside `Tests/`; it has no exemption list. "
    + "An `sql:` argument hands raw SQL text to an executor, outside swift-sql's typed statements and the "
    + "schema. Fix: express the statement with swift-sql (`@Table` query builders and `@Selection` rows) "
    + "and execute the typed statement; a fragment the builders cannot express yet becomes a `#sql` site, "
    + "which `sql fragment` and `sql registry` govern."

internal final class SQLLabelVisitor: SyntaxVisitor {
    var labels: [TokenSyntax] = []

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: LabeledExprSyntax) -> SyntaxVisitorContinueKind {
        guard let label = node.label, label.text == "sql",
            let list = node.parent?.as(LabeledExprListSyntax.self),
            let owner = list.parent
        else { return .visitChildren }
        if owner.is(FunctionCallExprSyntax.self)
            || owner.is(SubscriptCallExprSyntax.self)
            || owner.is(MacroExpansionExprSyntax.self)
            || owner.is(MacroExpansionDeclSyntax.self)
        {
            labels.append(label)
        }
        return .visitChildren
    }
}
