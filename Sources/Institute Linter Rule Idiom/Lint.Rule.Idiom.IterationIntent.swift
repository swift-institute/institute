public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `counter loop iteration` = Lint.Rule(
        id: "counter loop iteration",
        default: .warning,
        controls: [
            .init(
                id: "counter loop iteration range",
                source: "func scan(items: [Int]) { for index in 0..<items.count { use(items[index]) } }",
                path: "Sources/Idiom Core/CounterLoop.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "counter loop iteration indices",
                source: "func scan(items: [Int]) { items.indices.forEach { index in use(items[index]) } }",
                path: "Sources/Idiom Core/IndicesIteration.swift",
                expectation: .clean
            ),
            .init(
                id: "counter loop iteration elements",
                source: "func scan(items: [Int]) { for item in items { use(item) } }",
                path: "Sources/Idiom Core/ElementIteration.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = IdiomIterationIntentVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        },
        repair: { source in
            guard let contents = idiomIterationIntentFixed(source) else { return .unchanged }
            return .edits([.rewrite(path: source.path, contents: contents)])
        }
    )
}

@usableFromInline
internal let idiomIterationIntentMessage: Swift::String =
    "[counter loop iteration] [IMPL-033]: `for <name> in <a>..<<b>` "
    + "(or `.reversed()` of the same range) is mechanism, not intent. "
    + "This fires on any identifier-pattern range iteration, not only an "
    + "unused numeric counter — `for byte in first...last` is also "
    + "mechanism, not intent, even though `byte` is a meaningful name. "
    + "Climb the iteration ladder: `items.forEach { … }` (per-element), "
    + "`items.indices.forEach { … }` (when the index is needed), or a "
    + "typed-while inside iteration infrastructure if you're authoring "
    + "the infrastructure itself. **Already exempt** (rule does not fire): "
    + "a loop whose body performs a `try` inside a function declared with "
    + "typed throws (`throws(E)`) — `Sequence.forEach(_:)` is `rethrows` "
    + "and erases `throws(E)` to `any Error`, so the counter loop is the "
    + "lawful spelling there, not mechanism."

internal func idiomIsRangeExpression(_ expression: ExprSyntax) -> Swift::Bool {
    if idiomIsBareRangeExpression(expression) {
        return true
    }
    if let call = expression.as(FunctionCallExprSyntax.self),
        call.arguments.isEmpty,
        call.trailingClosure == nil,
        let member = call.calledExpression.as(MemberAccessExprSyntax.self),
        member.declName.baseName.text == "reversed"
    {
        return idiomIsBareRangeExpression(member.base?.unwrappingParens ?? ExprSyntax(call))
    }
    return false
}

private func idiomIsBareRangeExpression(_ expression: ExprSyntax) -> Swift::Bool {
    if let sequence = expression.as(SequenceExprSyntax.self) {
        for element in sequence.elements {
            if let binary = element.as(BinaryOperatorExprSyntax.self) {
                let text = binary.operator.text
                if text == "..<" || text == "..." { return true }
            }
        }
        return false
    }
    if let infix = expression.as(InfixOperatorExprSyntax.self) {
        if let binary = infix.operator.as(BinaryOperatorExprSyntax.self) {
            let text = binary.operator.text
            if text == "..<" || text == "..." { return true }
        }
    }
    return false
}

extension ExprSyntax {
    fileprivate var unwrappingParens: ExprSyntax {
        if let tuple = self.as(TupleExprSyntax.self), tuple.elements.count == 1,
            let onlyElement = tuple.elements.first, onlyElement.label == nil
        {
            return onlyElement.expression
        }
        return self
    }
}

internal func idiomLoopPreservesTypedThrows(_ loop: ForStmtSyntax) -> Swift::Bool {
    guard idiomContainsTryExpression(Syntax(loop.body)) else { return false }
    return idiomEnclosingDeclHasTypedThrows(Syntax(loop))
}

private func idiomContainsTryExpression(_ node: Syntax) -> Swift::Bool {
    if let tryExpr = node.as(TryExprSyntax.self), tryExpr.questionOrExclamationMark == nil {
        return true
    }
    for child in node.children(viewMode: .sourceAccurate) {
        if idiomContainsTryExpression(child) { return true }
    }
    return false
}

private func idiomEnclosingDeclHasTypedThrows(_ node: Syntax) -> Swift::Bool {
    var current: Syntax? = node.parent
    while let candidate = current {
        if let function = candidate.as(FunctionDeclSyntax.self) {
            return function.signature.effectSpecifiers?.throwsClause?.type != nil
        }
        if let initializer = candidate.as(InitializerDeclSyntax.self) {
            return initializer.signature.effectSpecifiers?.throwsClause?.type != nil
        }
        if let accessor = candidate.as(AccessorDeclSyntax.self) {
            return accessor.effectSpecifiers?.throwsClause?.type != nil
        }
        if let closure = candidate.as(ClosureExprSyntax.self) {
            return closure.signature?.effectSpecifiers?.throwsClause?.type != nil
        }
        current = candidate.parent
    }
    return false
}

internal final class IdiomIterationIntentVisitor: SyntaxVisitor {
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

    override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        guard node.pattern.is(IdentifierPatternSyntax.self) else { return .visitChildren }
        guard idiomIsRangeExpression(node.sequence) else { return .visitChildren }
        if idiomLoopPreservesTypedThrows(node) { return .visitChildren }
        let location = converter.location(for: node.forKeyword.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "counter loop iteration",
                message: idiomIterationIntentMessage
            )
        )
        return .visitChildren
    }
}
