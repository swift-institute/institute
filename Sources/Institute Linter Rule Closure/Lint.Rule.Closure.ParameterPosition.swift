public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `parameter position` = Lint.Rule(
        id: "parameter position",
        default: .warning,
        controls: [
            .init(
                id: "parameter position nonclosure after closure",
                source: "func perform(body: () -> Void, count: Int) {}",
                path: "Sources/Closure Core/ClosureThenValue.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "parameter position trailing closure",
                source: "func perform(count: Int, body: () -> Void) {}",
                path: "Sources/Closure Core/ValueThenClosure.swift",
                expectation: .clean
            ),
            .init(
                id: "parameter position trailing closures",
                source: "func perform(count: Int, body: () -> Void, completion: () -> Void) {}",
                path: "Sources/Closure Core/TrailingClosures.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ClosureParameterPositionVisitor(
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
internal let closureParameterPositionMessage: Swift::String =
    "[parameter position] [API-IMPL-012]: closure parameters MUST occupy the "
    + "final positions of the signature. A non-closure parameter MUST NOT appear "
    + "after a closure parameter — moves the trailing-closure call site. Reorder "
    + "non-closure parameters before all closure parameters; typed-throws thunks "
    + "(`() throws(E) -> T`) count as closures per [IMPL-092]."

internal func isClosureType(_ type: TypeSyntax) -> Swift::Bool {
    var current = closureStrippingWrapperTypes(type)
    while let tuple = current.as(TupleTypeSyntax.self), tuple.elements.count == 1,
        let element = tuple.elements.first
    {
        current = element.type
    }
    return current.is(FunctionTypeSyntax.self)
}

internal final class ClosureParameterPositionVisitor: SyntaxVisitor {
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

    private func emit(at position: AbsolutePosition) {
        let location = converter.location(for: position)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "parameter position",
                message: closureParameterPositionMessage
            )
        )
    }

    private func checkParameters(_ parameters: FunctionParameterListSyntax) {
        var sawClosure = false
        for parameter in parameters {
            let isClosure = isClosureType(parameter.type)
            if sawClosure, !isClosure {
                emit(at: parameter.firstName.positionAfterSkippingLeadingTrivia)
            }
            if isClosure {
                sawClosure = true
            }
        }
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }
}
