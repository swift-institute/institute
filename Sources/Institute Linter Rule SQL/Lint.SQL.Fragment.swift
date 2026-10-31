package import Lint
internal import Linter_Rule_Scope
package import SwiftSyntax

extension Lint.SQL {

    package enum Fragment {}
}

extension Lint.SQL.Fragment {

    package static let identifier: Swift::String = "sql fragment"

    package static let scope: Swift::String =
        "This rule checks every `#sql` outside a `… Schema` target and `Tests/`: it must be a fragment the "
        + "builder cannot express, not a whole statement (an upper-case SELECT … FROM, INSERT INTO, UPDATE … "
        + "SET, DELETE FROM, WITH … SELECT, CREATE, ALTER or DROP of a table, PRAGMA, REPLACE INTO or BEGIN "
        + "TRANSACTION first), must name no table or column by a quoted identifier, "
        + "and must interpolate at least one column, table or value. It does not check that the builder "
        + "really cannot express it; `sql registry` asks for that reason."

    package enum Problem: Sendable, Equatable {
        case statement
        case quoted
        case literal
    }

    package static func observe(
        _ source: borrowing Lint.Source.Parsed,
        severity: Diagnostic.Severity
    ) -> Lint.Rule.Observation {
        guard !Lint.Scope.Target.named(source.path, suffix: " Schema"), !Lint.Scope.Target.isTest(source.path) else {
            return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
        }
        let visitor = Visitor()
        visitor.walk(source.tree)
        let findings = visitor.sites.compactMap { site -> Diagnostic.Record? in
            guard let problem = problem(of: site.literal) else { return nil }
            return Lint.Scope.record(
                at: site.macro,
                in: source,
                severity: severity,
                identifier: identifier,
                message: "[sql fragment]: \(message(problem)) \(scope)"
            )
        }
        return Lint.Rule.Observation(findings: findings, coverage: .measured)
    }

    package static func problem(of literal: StringLiteralExprSyntax) -> Problem? {
        if Lint.SQL.Statement.leads(Lint.SQL.Statement.text(of: literal)) { return .statement }
        if quotes(literal) { return .quoted }
        if !literal.segments.contains(where: { $0.is(ExpressionSegmentSyntax.self) }) { return .literal }
        return nil
    }

    package static func message(_ problem: Problem) -> Swift::String {
        switch problem {
        case .statement:
            "this `#sql` is a whole statement. Fix: build it with swift-sql (`@Table` and `@Selection`, "
                + "`With` for a common table expression), or move schema into the `… Schema` target."
        case .quoted:
            "this `#sql` names a table or column by a quoted identifier, which the schema does not check. "
                + "Fix: interpolate the column (`\\(Table.columns.name)`) or the table (`\\(Table.self)`)."
        case .literal:
            "this `#sql` interpolates nothing, so it is SQL text the builder could state. Fix: use the "
                + "builder (`true`, a column, an operator) or interpolate the columns it reads."
        }
    }

    fileprivate static func quotes(_ literal: StringLiteralExprSyntax) -> Swift::Bool {
        for segment in literal.segments {
            guard let plain = segment.as(StringSegmentSyntax.self) else { continue }
            let text = plain.content.text
            let raw = literal.openingPounds != nil || literal.openingQuote.tokenKind == .multilineStringQuote
            if raw, text.contains("\"") { return true }
            if text.contains("\\\"") { return true }
        }
        return false
    }
}

extension Lint.SQL.Fragment {

    fileprivate struct Site {
        let macro: Syntax
        let literal: StringLiteralExprSyntax
    }

    fileprivate final class Visitor: SyntaxVisitor {
        var sites: [Site] = []

        init() {
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
            record(Syntax(node), name: node.macroName.text, arguments: node.arguments)
            return .visitChildren
        }

        override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
            record(Syntax(node), name: node.macroName.text, arguments: node.arguments)
            return .visitChildren
        }

        func record(_ macro: Syntax, name: Swift::String, arguments: LabeledExprListSyntax) {
            guard name == "sql", let first = arguments.first, first.label == nil,
                let literal = first.expression.as(StringLiteralExprSyntax.self)
            else { return }
            sites.append(Site(macro: macro, literal: literal))
        }
    }
}
