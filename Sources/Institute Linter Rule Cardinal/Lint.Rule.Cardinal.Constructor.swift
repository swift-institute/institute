public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `zero or one literal` = Lint.Rule(
        id: "zero or one literal",
        default: .warning,
        controls: [
            .init(
                id: "zero or one literal cardinal zero",
                source: "let value = Cardinal(0)",
                path: "Sources/Cardinal Consumer/CardinalZero.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "zero or one literal cardinal two",
                source: "let value = Cardinal(2)",
                path: "Sources/Cardinal Consumer/CardinalTwo.swift",
                expectation: .clean
            ),
            .init(
                id: "zero or one literal other type",
                source: "let value = Ordinal(1)",
                path: "Sources/Cardinal Consumer/OrdinalOne.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            if Lint.Brand.owned(["Cardinal"], in: source) { return [] }
            let visitor = CardinalConstructorVisitor(
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
internal let cardinalZeroOneConstructorMessage: Swift::String =
    "[zero or one literal] [INFRA-101]: `Cardinal(0)` / `Cardinal(1)` "
    + "constructor calls with literal `0` or `1` bypass the typed-system literal "
    + "discipline. Use the canonical accessors `.zero` / `.one` instead. If this site "
    + "is the typed-system bottom-out, escalate to supervisor and apply "
    + "`// swift-linter:disable:next zero or one literal` with a "
    + "`// REASON: <citation>` continuation."

internal final class CardinalConstructorVisitor: SyntaxVisitor {
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

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard Self.calleeTypeName(node.calledExpression) == "Cardinal" else {
            return .visitChildren
        }
        guard node.arguments.count == 1, let arg = node.arguments.first else {
            return .visitChildren
        }
        guard arg.label == nil else { return .visitChildren }
        guard let lit = arg.expression.as(IntegerLiteralExprSyntax.self) else {
            return .visitChildren
        }
        guard lit.literal.text == "0" || lit.literal.text == "1" else {
            return .visitChildren
        }
        guard let token = node.calledExpression.firstToken(viewMode: .sourceAccurate) else {
            return .visitChildren
        }
        let location = converter.location(for: token.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "zero or one literal",
                message: cardinalZeroOneConstructorMessage
            )
        )
        return .visitChildren
    }

    static func calleeTypeName(_ expr: ExprSyntax) -> Swift::String? {
        if let ref = expr.as(DeclReferenceExprSyntax.self) {
            return ref.baseName.text
        }
        if let generic = expr.as(GenericSpecializationExprSyntax.self) {
            return calleeTypeName(generic.expression)
        }
        if let member = expr.as(MemberAccessExprSyntax.self) {
            if member.declName.baseName.text == "init", let base = member.base {
                return calleeTypeName(base)
            }
            return member.declName.baseName.text
        }
        return nil
    }
}
