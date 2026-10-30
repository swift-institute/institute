public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `sli literal` = Lint.Rule(
        id: "sli literal",
        default: .warning,
        controls: [
            .init(
                id: "sli literal Index literal",
                source: "func read(slab: Slab) { _ = slab[Index<Int>(Ordinal(UInt(0)))] }",
                path: "Sources/Idiom Core/IndexLiteral.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "sli literal bare literal",
                source: "func read(slab: Slab) { _ = slab[0] }",
                path: "Sources/Idiom Core/BareLiteral.swift",
                expectation: .clean
            ),
            .init(
                id: "sli literal runtime",
                source: "func read(slot: UInt) { _ = Index<Int>(Ordinal(UInt(slot))) }",
                path: "Sources/Idiom Core/RuntimeIndex.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = IdiomSliLiteralVisitor(
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
internal let idiomSliLiteralMessage: Swift::String =
    "[sli literal] [IDX-019]: verbose compile-time-constant "
    + "`Index`/`Tagged` construction wraps an integer literal in "
    + "`Ordinal(UInt(…))`. The tagged SLI carve-out "
    + "(`Tagged: ExpressibleByIntegerLiteral`) makes literals infer — "
    + "write the bare integer literal (e.g. `slab[0]`). Keep the explicit "
    + "`Index<Element>(Ordinal(UInt(x)))` construction only for runtime "
    + "values (identifiers, member accesses, call results)."

internal func idiomSliOuterCalleeName(_ call: FunctionCallExprSyntax) -> Swift::String? {
    let callee = call.calledExpression
    if let reference = callee.as(DeclReferenceExprSyntax.self) {
        return reference.baseName.text
    }
    if let specialization = callee.as(GenericSpecializationExprSyntax.self),
        let reference = specialization.expression.as(DeclReferenceExprSyntax.self)
    {
        return reference.baseName.text
    }
    return nil
}

internal func idiomSliBareCalleeName(_ call: FunctionCallExprSyntax) -> Swift::String? {
    call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text
}

internal func idiomSliSingleUnlabeledArgument(_ call: FunctionCallExprSyntax) -> ExprSyntax? {
    guard call.trailingClosure == nil,
        call.additionalTrailingClosures.isEmpty,
        call.arguments.count == 1,
        let only = call.arguments.first,
        only.label == nil
    else { return nil }
    return only.expression
}

internal final class IdiomSliLiteralVisitor: SyntaxVisitor {
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
        guard let outerName = idiomSliOuterCalleeName(node),
            outerName == "Index" || outerName == "Tagged",
            let ordinalArgument = idiomSliSingleUnlabeledArgument(node),
            let ordinalCall = ordinalArgument.as(FunctionCallExprSyntax.self),
            idiomSliBareCalleeName(ordinalCall) == "Ordinal",
            let uintArgument = idiomSliSingleUnlabeledArgument(ordinalCall),
            let uintCall = uintArgument.as(FunctionCallExprSyntax.self),
            idiomSliBareCalleeName(uintCall) == "UInt",
            let innerArgument = idiomSliSingleUnlabeledArgument(uintCall),
            innerArgument.is(IntegerLiteralExprSyntax.self)
        else { return .visitChildren }

        let location = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "sli literal",
                message: idiomSliLiteralMessage
            )
        )
        return .visitChildren
    }
}
