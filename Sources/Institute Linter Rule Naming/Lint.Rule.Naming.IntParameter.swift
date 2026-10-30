public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `int public parameter` = Lint.Rule(
        id: "int public parameter",
        default: .warning,
        controls: [
            .init(
                id: "int public parameter public int",
                source: "public func read(count: Int) {}",
                path: "Sources/Naming Core/PublicInt.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "int public parameter internal int",
                source: "func read(count: Int) {}",
                path: "Sources/Naming Core/InternalInt.swift",
                expectation: .clean
            ),
            .init(
                id: "int public parameter cardinal",
                source: "public func read(count: Cardinal) {}",
                path: "Sources/Naming Core/Cardinal.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            if Lint.Brand.owned(Lint.Brand.vocabulary, in: source) { return [] }
            let visitor = NamingIntParameterVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let namingIntParameterMessageParameter: Swift::String =
    "[int public parameter] [IMPL-010]: public function/initializer/subscript "
    + "signature has a bare `Int` parameter. Push the stdlib boundary "
    + "out — use a typed wrapper (`Index<T>`, `Ordinal`, `Cardinal`, "
    + "`Count<T>`, `Offset<T>`) at the public surface; convert via a "
    + "boundary overload internally. `Int(bitPattern:)` lives in one "
    + "place, once, forever (per [IMPL-010])."

private let namingIntParameterMessageReturn: Swift::String =
    "[int public parameter] [IMPL-010]: public function/subscript returns a "
    + "bare `Int`. Push the stdlib boundary out — return a typed wrapper "
    + "(`Cardinal`, `Count<T>`, `Offset<T>`) so consumers see typed "
    + "intent rather than a raw machine integer."

private func namingIntParameterIsBareInt(_ type: TypeSyntax) -> Bool {
    var current = type
    while let optional = current.as(OptionalTypeSyntax.self) {
        current = optional.wrappedType
    }
    while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        current = iuo.wrappedType
    }
    while let attributed = current.as(AttributedTypeSyntax.self) {
        current = attributed.baseType
    }
    while let tuple = current.as(TupleTypeSyntax.self), tuple.elements.count == 1,
        let element = tuple.elements.first
    {
        current = element.type
    }
    if let identifier = current.as(IdentifierTypeSyntax.self) {
        return identifier.name.text == "Int"
    }
    if let member = current.as(MemberTypeSyntax.self) {
        if member.name.text == "Int",
            let baseIdentifier = member.baseType.as(IdentifierTypeSyntax.self),
            baseIdentifier.name.text == "Swift"
        {
            return true
        }
    }
    return false
}

internal final class NamingIntParameterVisitor: SyntaxVisitor {
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

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard Naming.hasPublicOrOpenEffective(Syntax(node), modifiers: node.modifiers) else {
            return .visitChildren
        }
        if Naming.Build.methods.contains(node.name.text),
            Naming.isInsideExtensionPattern(Syntax(node))
        {
            return .visitChildren
        }
        checkParameters(node.signature.parameterClause.parameters)
        if let returnClause = node.signature.returnClause,
            namingIntParameterIsBareInt(returnClause.type)
        {
            emit(
                at: returnClause.type.positionAfterSkippingLeadingTrivia,
                message: namingIntParameterMessageReturn
            )
        }
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard Naming.hasPublicOrOpenEffective(Syntax(node), modifiers: node.modifiers) else {
            return .visitChildren
        }
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        guard Naming.hasPublicOrOpenEffective(Syntax(node), modifiers: node.modifiers) else {
            return .visitChildren
        }
        checkParameters(node.parameterClause.parameters)
        if namingIntParameterIsBareInt(node.returnClause.type) {
            emit(
                at: node.returnClause.type.positionAfterSkippingLeadingTrivia,
                message: namingIntParameterMessageReturn
            )
        }
        return .visitChildren
    }

    private func checkParameters(_ parameters: FunctionParameterListSyntax) {
        for parameter in parameters {
            guard namingIntParameterIsBareInt(parameter.type) else {
                continue
            }
            emit(
                at: parameter.firstName.positionAfterSkippingLeadingTrivia,
                message: namingIntParameterMessageParameter
            )
        }
    }

    private func emit(at position: AbsolutePosition, message: Swift::String) {
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
                identifier: "int public parameter",
                message: message
            )
        )
    }
}
