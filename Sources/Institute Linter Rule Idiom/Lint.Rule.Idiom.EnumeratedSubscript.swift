public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `enumerated with subscript` = Lint.Rule(
        id: "enumerated with subscript",
        default: .warning,
        controls: [
            .init(
                id: "enumerated with subscript same receiver",
                source: "func scan(items: [Int]) { for (index, _) in items.enumerated() { use(items[index]) } }",
                path: "Sources/Idiom Core/EnumeratedSubscript.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "enumerated with subscript element",
                source: "func scan(items: [Int]) { for (_, element) in items.enumerated() { use(element) } }",
                path: "Sources/Idiom Core/EnumeratedElement.swift",
                expectation: .clean
            ),
            .init(
                id: "enumerated with subscript other receiver",
                source: "func scan(items: [Int], other: [Int]) { for (index, _) in items.enumerated() { use(other[index]) } }",
                path: "Sources/Idiom Core/EnumeratedOther.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = IdiomEnumeratedSubscriptVisitor(
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
internal let idiomEnumeratedSubscriptMessage: Swift::String =
    "[enumerated with subscript] [PATTERN-058]: `for (i, _) in "
    + "<seq>.enumerated() { ... <seq>[i] }` works on Array but silently "
    + "breaks on custom Collections whose `Index` is not a 0-based offset "
    + "(byte position, token offset). Prefer iterator-based comparison or "
    + "`zip(a, b)`. Suppress with a `// swift-linter:disable:next enumerated with subscript` "
    + "and `// REASON:` continuation for confirmed Array call sites."

internal func idiomLoopIndexName(_ pattern: PatternSyntax) -> Swift::String? {
    guard let tuple = pattern.as(TuplePatternSyntax.self) else { return nil }
    guard tuple.elements.count == 2 else { return nil }
    guard let first = tuple.elements.first?.pattern.as(IdentifierPatternSyntax.self) else {
        return nil
    }
    return first.identifier.text
}

internal func idiomNormalizedReceiverPath(_ expression: ExprSyntax) -> Swift::String? {
    if let reference = expression.as(DeclReferenceExprSyntax.self) {
        return reference.baseName.text
    }
    if let member = expression.as(MemberAccessExprSyntax.self) {
        guard let base = member.base else {
            return nil
        }
        if let baseReference = base.as(DeclReferenceExprSyntax.self),
            baseReference.baseName.text == "self"
        {
            return member.declName.baseName.text
        }
        guard let basePath = idiomNormalizedReceiverPath(base) else { return nil }
        return basePath + "." + member.declName.baseName.text
    }
    return nil
}

internal func idiomEnumeratedReceiverText(_ sequence: ExprSyntax) -> Swift::String? {
    guard let call = sequence.as(FunctionCallExprSyntax.self) else { return nil }
    guard let member = call.calledExpression.as(MemberAccessExprSyntax.self) else { return nil }
    guard member.declName.baseName.text == "enumerated" else { return nil }
    guard call.arguments.isEmpty else { return nil }
    guard let base = member.base else { return nil }
    return idiomNormalizedReceiverPath(base)
}

internal final class IdiomEnumeratedSubscriptVisitor: SyntaxVisitor {
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
        guard let indexName = idiomLoopIndexName(node.pattern) else { return .visitChildren }
        guard let receiverText = idiomEnumeratedReceiverText(node.sequence) else {
            return .visitChildren
        }
        let search = IdiomEnumeratedSubscriptBodySearch(
            indexName: indexName,
            receiverText: receiverText
        )
        search.walk(node.body)
        guard !search.hits.isEmpty else { return .visitChildren }
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
                identifier: "enumerated with subscript",
                message: idiomEnumeratedSubscriptMessage
            )
        )
        return .visitChildren
    }
}
