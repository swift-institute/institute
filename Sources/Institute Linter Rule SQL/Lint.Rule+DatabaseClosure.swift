public import Lint
internal import Linter_Rule_Scope
internal import SwiftSyntax

extension Lint.Rule {

    public static let `database closure type` = Lint.Rule(
        id: "database closure type",
        default: .warning,
        controls: [
            .init(
                id: "untyped multi-statement read",
                source: """
                    func keys() throws -> [Int] {
                      try database.read { db in
                        if let pattern { return try Text.keys(matching: pattern).fetchAll(db) }
                        return try Text.keys.fetchAll(db)
                      }
                    }
                    """,
                path: "Controls/DatabaseClosureType.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "single return statement read",
                source: """
                    func count() throws -> Int? {
                      try database.read { db in
                        return try Text.count.fetchOne(db)
                      }
                    }
                    """,
                path: "Controls/DatabaseClosureTypeReturn.swift",
                expectation: .clean
            ),
            .init(
                id: "typed multi-statement read",
                source: """
                    func keys() throws -> [Int] {
                      try database.read { (db: SQLite.Connection) throws -> [Int] in
                        if let pattern { return try Text.keys(matching: pattern).fetchAll(db) }
                        return try Text.keys.fetchAll(db)
                      }
                    }
                    """,
                path: "Controls/DatabaseClosureTypeTyped.swift",
                expectation: .clean
            ),
        ],
        observe: { source, severity in
            let visitor = DatabaseClosureVisitor()
            visitor.walk(source.tree)
            let findings = visitor.closures.map { closure in
                Lint.Scope.record(
                    at: closure.leftBrace,
                    in: source,
                    severity: severity,
                    identifier: "database closure type",
                    message: `database closure type message`
                )
            }
            return Lint.Rule.Observation(findings: findings, coverage: .measured)
        }
    )
}

package let `database closure type message`: Swift::String =
    "[database closure type]: checks every closure passed to `read`, `write`, `writeWithoutTransaction`, "
    + "`withRollback` or `observe` that has more than one statement and returns a value: it must state its "
    + "result type. Inferring the result from several `return`s is where the compiler hung, for 27 to 37 "
    + "minutes, on a name that did not resolve inside such a closure, instead of reporting it "
    + "(swift-institute/Issues#181). Fix: write the closure's signature, `{ (db: SQLite.Connection) throws "
    + "-> Value in … }`, or make its body one expression. The rule checks that the type is written, not "
    + "that the body is otherwise easy to type-check."

internal final class DatabaseClosureVisitor: SyntaxVisitor {
    var closures: [ClosureExprSyntax] = []

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
            Lint.SQL.Edge.edges.contains(member.declName.baseName.text)
        else { return .visitChildren }
        let arguments = node.arguments.compactMap { $0.expression.as(ClosureExprSyntax.self) }
        let trailing = [node.trailingClosure].compactMap { $0 } + node.additionalTrailingClosures.map(\.closure)
        for closure in arguments + trailing where Self.untyped(closure) {
            closures.append(closure)
        }
        return .visitChildren
    }

    /// Whether `closure` has more than one statement, returns a value, and does not state its result type.
    static func untyped(_ closure: ClosureExprSyntax) -> Bool {
        guard closure.signature?.returnClause == nil else { return false }
        let statements = closure.statements
        guard statements.count > 1 else { return false }
        let returns = ReturnVisitor()
        returns.walk(statements)
        return returns.found
    }
}

/// Finds a `return` with a value in a closure's own body, never in a closure or function nested in it.
internal final class ReturnVisitor: SyntaxVisitor {
    var found = false

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ReturnStmtSyntax) -> SyntaxVisitorContinueKind {
        if node.expression != nil { found = true }
        return .skipChildren
    }

    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: AccessorBlockSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
}
