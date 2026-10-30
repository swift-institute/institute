public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `statement where expression fits` = Lint.Rule(
        id: "statement where expression fits",
        default: .warning,
        controls: [
            .init(
                id: "statement where expression fits returns",
                source: "func f(_ flag: Bool) -> Int { if flag { return 1 } else { return 2 } }",
                path: "Sources/Idiom Consumer/Choice.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "statement where expression fits assignments",
                source: "func f(_ flag: Bool) { var value = 0; if flag { value = 1 } else { value = 2 }; use(value) }",
                path: "Sources/Idiom Consumer/Choice.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "statement where expression fits expression",
                source: "func f(_ flag: Bool) -> Int { if flag { 1 } else { 2 } }",
                path: "Sources/Idiom Consumer/Choice.swift",
                expectation: .clean
            ),
            .init(
                id: "statement where expression fits no else",
                source: "func f(_ flag: Bool) -> Int { if flag { return 1 }; return 2 }",
                path: "Sources/Idiom Consumer/Choice.swift",
                expectation: .clean
            ),
            .init(
                id: "statement where expression fits mixed",
                source: "func f(_ flag: Bool) -> Int { if flag { return 1 } else { log(); return 2 } }",
                path: "Sources/Idiom Consumer/Choice.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = IdiomStatementWhereExpressionFitsVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let idiomStatementWhereExpressionFitsMessage: Swift::String =
    "[statement where expression fits] [SOURCE-EXPRESSION-OVER-STATEMENT]: every "
    + "branch of this `if` returns or assigns one value; write it as an `if` or "
    + "`switch` expression (`return if ...`, `let x = if ...`) or a ternary."

internal final class IdiomStatementWhereExpressionFitsVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ExpressionStmtSyntax) -> SyntaxVisitorContinueKind {
        guard let chain = node.expression.as(IfExprSyntax.self),
            let branches = branches(of: chain),
            let first = branches.first,
            first != nil,
            branches.allSatisfy({ $0 == first })
        else {
            return .visitChildren
        }
        let location = converter.location(for: chain.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "statement where expression fits",
                message: idiomStatementWhereExpressionFitsMessage
            )
        )
        return .visitChildren
    }

    private func branches(of node: IfExprSyntax) -> [Swift::String?]? {
        let head = shape(of: node.body)
        return switch node.elseBody {
        case .none: nil
        case .codeBlock(let block)?: [head, shape(of: block)]
        case .ifExpr(let next)?: branches(of: next).map { [head] + $0 }
        }
    }

    private func shape(of block: CodeBlockSyntax) -> Swift::String? {
        guard block.statements.count == 1, let item = block.statements.first?.item else {
            return nil
        }
        if let statement = item.as(ReturnStmtSyntax.self) {
            return statement.expression == nil ? nil : "return"
        }
        let expression = item.as(ExpressionStmtSyntax.self)?.expression ?? item.as(ExprSyntax.self)
        guard let sequence = expression?.as(SequenceExprSyntax.self),
            sequence.elements.count == 3
        else {
            return nil
        }
        let elements = Swift::Array(sequence.elements)
        guard elements[1].is(AssignmentExprSyntax.self),
            let target = elements[0].as(DeclReferenceExprSyntax.self)
        else {
            return nil
        }
        return "assign " + target.baseName.text
    }
}
