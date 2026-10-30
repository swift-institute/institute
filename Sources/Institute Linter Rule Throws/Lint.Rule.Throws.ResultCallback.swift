public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `callback result over throws thunk` = Lint.Rule(
        id: "callback result over throws thunk",
        default: .warning,
        controls: [
            .init(
                id: "callback result over throws thunk result callback",
                source: "func register(_ callback: (Result<Int, Read.Error>) -> Void) {}",
                path: "Sources/Throws Consumer/ResultCallback.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "callback result over throws thunk typed thunk",
                source: "func register(_ callback: (() throws(Read.Error) -> Int) -> Void) {}",
                path: "Sources/Throws Consumer/TypedThunkCallback.swift",
                expectation: .clean
            ),
            .init(
                id: "callback result over throws thunk return value",
                source: "func read() -> Result<Int, Read.Error> { fatalError() }",
                path: "Sources/Throws Consumer/ResultReturn.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ThrowsResultCallbackVisitor(
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
internal let throwsResultCallbackMessage: Swift::String =
    "[callback result over throws thunk] [IMPL-092]: callback closure "
    + "parameters MUST deliver outcomes via a `() throws(E) -> T` thunk, "
    + "not a `Result<T, E>` value."

private func resultCallbackTokenPosition(in type: TypeSyntax) -> AbsolutePosition? {
    var current = type
    while let optional = current.as(OptionalTypeSyntax.self) { current = optional.wrappedType }
    while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        current = iuo.wrappedType
    }
    while let attributed = current.as(AttributedTypeSyntax.self) { current = attributed.baseType }
    if let identifier = current.as(IdentifierTypeSyntax.self),
        identifier.name.text == "Result",
        identifier.genericArgumentClause?.arguments.count == 2
    {
        return identifier.name.positionAfterSkippingLeadingTrivia
    }
    if let member = current.as(MemberTypeSyntax.self),
        member.name.text == "Result",
        member.genericArgumentClause?.arguments.count == 2,
        let base = member.baseType.as(IdentifierTypeSyntax.self),
        base.name.text == "Swift"
    {
        return member.name.positionAfterSkippingLeadingTrivia
    }
    if let array = current.as(ArrayTypeSyntax.self) {
        return resultCallbackTokenPosition(in: array.element)
    }
    if let tuple = current.as(TupleTypeSyntax.self) {
        for element in tuple.elements {
            if let position = resultCallbackTokenPosition(in: element.type) { return position }
        }
        return nil
    }
    if let dictionary = current.as(DictionaryTypeSyntax.self) {
        return resultCallbackTokenPosition(in: dictionary.value)
    }
    return nil
}

internal final class ThrowsResultCallbackVisitor: SyntaxVisitor {
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

    override func visit(_ node: FunctionTypeSyntax) -> SyntaxVisitorContinueKind {
        for parameter in node.parameters {
            if let position = resultCallbackTokenPosition(in: parameter.type) {
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
                        identifier: "callback result over throws thunk",
                        message: throwsResultCallbackMessage
                    )
                )
            }
        }
        return .visitChildren
    }
}
