public import Lint
internal import SwiftOperators
internal import SwiftSyntax

extension Lint.Rule {
    public static let `count minus one` = Lint.Rule(
        id: "count minus one",
        default: .warning,
        controls: [
            .init(
                id: "count minus one member access",
                source: "let last = values.count - 1",
                path: "Sources/Cardinal Consumer/MemberCount.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "count minus one different literal",
                source: "let remaining = values.count - 2",
                path: "Sources/Cardinal Consumer/CountMinusTwo.swift",
                expectation: .clean
            ),
            .init(
                id: "count minus one bare binding",
                source: "let count = limit\nlet last = count - 1",
                path: "Sources/Cardinal Consumer/BareCount.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let folded = OperatorTable.standardOperators.foldAll(
                source.tree,
                errorHandler: { _ in }
            )
            let visitor = CardinalCountVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(folded)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let cardinalCountMinusOneMessage: Swift::String =
    "[count minus one] [INFRA-200]: `<expr>.count - 1` (or syntactic "
    + "equivalents — paren-wrap `(seq.count) - 1`, cast-outside `Double(seq.count) - 1`, "
    + "algebraic-flip `+ 1 [<=] seq.count`, operand-reorder `seq.count - i - 1`) "
    + "indicates `count: Int` not `count: Cardinal` (the typed form would not compile). "
    + "Use `.subtract.saturating(.one)` / `.subtract.exact(.one)` / typed `count - .one` "
    + "per [INFRA-025], or for stdlib-Int sites where no typed surface is available "
    + "either (α) use the stdlib's named idiom for the concept (`indices.dropLast()`, "
    + "`.last`, `endIndex - 1`) or (β) escalate to supervisor and apply "
    + "`// swift-linter:disable:next count minus one` with a "
    + "`// REASON: <citation>` continuation."

internal final class CardinalCountVisitor: SyntaxVisitor {
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

    override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        guard let binOp = node.operator.as(BinaryOperatorExprSyntax.self) else {
            return .visitChildren
        }
        let opText = binOp.operator.text

        if opText == "-",
            Self.isLiteralOne(node.rightOperand),
            Self.isCountDerivedExpression(node.leftOperand)
        {
            report(at: binOp.operator)
            return .visitChildren
        }

        if Self.isComparisonOperator(opText) {
            if Self.isIndexPlusOne(node.leftOperand),
                Self.isCountDerivedExpression(node.rightOperand)
            {
                report(at: binOp.operator)
            } else if Self.isIndexPlusOne(node.rightOperand),
                Self.isCountDerivedExpression(node.leftOperand)
            {
                report(at: binOp.operator)
            }
        }

        return .visitChildren
    }

    func report(at token: TokenSyntax) {
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
                identifier: "count minus one",
                message: cardinalCountMinusOneMessage
            )
        )
    }

    static func isLiteralOne(_ expr: ExprSyntax) -> Bool {
        guard let lit = expr.as(IntegerLiteralExprSyntax.self) else { return false }
        return lit.literal.text == "1"
    }

    static func isComparisonOperator(_ text: Swift::String) -> Bool {
        switch text {
        case "<", "<=", "==", "!=", ">=", ">": return true
        default: return false
        }
    }

    static func isPlusOne(_ expr: ExprSyntax) -> Bool {
        guard let infix = expr.as(InfixOperatorExprSyntax.self),
            let binOp = infix.operator.as(BinaryOperatorExprSyntax.self),
            binOp.operator.text == "+"
        else { return false }
        return isLiteralOne(infix.leftOperand) || isLiteralOne(infix.rightOperand)
    }

    static func isIndexPlusOne(_ expr: ExprSyntax) -> Bool {
        guard let infix = expr.as(InfixOperatorExprSyntax.self),
            let binOp = infix.operator.as(BinaryOperatorExprSyntax.self),
            binOp.operator.text == "+"
        else { return false }
        if isLiteralOne(infix.rightOperand) {
            return !isCountDerivedExpression(infix.leftOperand)
        }
        if isLiteralOne(infix.leftOperand) {
            return !isCountDerivedExpression(infix.rightOperand)
        }
        return false
    }

    static func isCountDerivedExpression(_ expr: ExprSyntax) -> Bool {
        let unwrapped = peelCountWrappers(expr)
        if let member = unwrapped.as(MemberAccessExprSyntax.self),
            member.declName.baseName.text == "count"
        {
            return true
        }
        if let infix = unwrapped.as(InfixOperatorExprSyntax.self),
            let binOp = infix.operator.as(BinaryOperatorExprSyntax.self),
            binOp.operator.text == "-"
        {
            return isCountDerivedExpression(infix.leftOperand)
        }
        return false
    }

    static func peelCountWrappers(_ expr: ExprSyntax) -> ExprSyntax {
        var current = expr
        while true {
            if let tuple = current.as(TupleExprSyntax.self),
                tuple.elements.count == 1,
                let only = tuple.elements.first?.expression,
                tuple.elements.first?.label == nil
            {
                current = only
                continue
            }
            if let call = current.as(FunctionCallExprSyntax.self),
                call.arguments.count == 1,
                let onlyArg = call.arguments.first,
                onlyArg.label == nil,
                call.trailingClosure == nil
            {
                current = onlyArg.expression
                continue
            }
            break
        }
        return current
    }
}
