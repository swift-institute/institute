public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `bounded index static capacity` = Lint.Rule(
        id: "bounded index static capacity",
        default: .warning,
        controls: [
            .init(
                id: "bounded index static capacity raw Int",
                source: "struct Buffer<let N: Int> { subscript(index: Int) -> Int { 0 } }",
                path: "Sources/Idiom Core/RawIndex.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "bounded index static capacity bounded",
                source: "struct Buffer<let N: Int> { subscript(index: Index<Int>.Bounded<N>) -> Int { 0 } }",
                path: "Sources/Idiom Core/BoundedIndex.swift",
                expectation: .clean
            ),
            .init(
                id: "bounded index static capacity raw Int in same-file extension",
                source: "struct Buffer<let N: Int> {}\nextension Buffer { subscript(index: Int) -> Int { 0 } }",
                path: "Sources/Idiom Core/ExtensionIndex.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "bounded index static capacity nested type extension",
                source: "extension Bitset { struct Static<let N: Int> {} }\nextension Bitset.Static { subscript(index: Int) -> Bool { false } }",
                path: "Sources/Idiom Core/NestedExtensionIndex.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "bounded index static capacity extension of a dynamic type",
                source: "struct Buffer<let N: Int> {}\nstruct Other {}\nextension Other { subscript(index: Int) -> Int { 0 } }",
                path: "Sources/Idiom Core/OtherIndex.swift",
                expectation: .clean
            ),
            .init(
                id: "bounded index static capacity dynamic",
                source: "struct Buffer { subscript(index: Int) -> Int { 0 } }",
                path: "Sources/Idiom Core/DynamicIndex.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let types = IdiomValueGenericTypeCollector(viewMode: .sourceAccurate)
            types.walk(source.tree)
            let visitor = IdiomBoundedIndexVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter,
                valueGenericTypes: types.names.union(source.index.valueGenericTypes)
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let idiomBoundedIndexMessage: Swift::String =
    "[bounded index static capacity] [IMPL-050]: subscript on a "
    + "static-capacity type (`<let N: Int>`) takes a raw `Int` index — "
    + "the capacity bound is dropped from the type system. Use "
    + "`Index<Element>.Bounded<N>` so the index cannot exceed `N` at "
    + "authoring time. Per [IMPL-052], unbounded variants MUST NOT "
    + "co-exist alongside bounded ones — bounded is the sole public API."

internal func idiomHasValueGenericParameter(_ clause: GenericParameterClauseSyntax?) -> Swift::Bool {
    guard let clause else { return false }
    for parameter in clause.parameters {
        if let specifier = parameter.specifier,
            case .keyword(.let) = specifier.tokenKind
        {
            return true
        }
    }
    return false
}

internal func idiomIsRawIntType(_ type: TypeSyntax) -> Swift::Bool {
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
    if let identifier = current.as(IdentifierTypeSyntax.self),
        identifier.name.text == "Int"
    {
        return true
    }
    if let member = current.as(MemberTypeSyntax.self),
        member.name.text == "Int",
        let base = member.baseType.as(IdentifierTypeSyntax.self),
        base.name.text == "Swift"
    {
        return true
    }
    return false
}

internal func idiomTypeNames(of type: TypeSyntax) -> [Swift::String] {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return [identifier.name.text]
    }
    if let member = type.as(MemberTypeSyntax.self) {
        return [member.name.text, member.trimmedDescription]
    }
    return []
}

internal final class IdiomValueGenericTypeCollector: SyntaxVisitor {
    var names: Swift::Set<Swift::String> = []
    private func record(_ node: Syntax, name: TokenSyntax, clause: GenericParameterClauseSyntax?) {
        guard idiomHasValueGenericParameter(clause) else { return }
        names.insert(name.text)
        var qualified = name.text
        var current = node.parent
        while let candidate = current {
            if let decl = candidate.as(StructDeclSyntax.self) {
                qualified = decl.name.text + "." + qualified
            } else if let decl = candidate.as(EnumDeclSyntax.self) {
                qualified = decl.name.text + "." + qualified
            } else if let decl = candidate.as(ExtensionDeclSyntax.self) {
                qualified = decl.extendedType.trimmedDescription + "." + qualified
                break
            }
            current = candidate.parent
        }
        names.insert(qualified)
    }
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        record(Syntax(node), name: node.name, clause: node.genericParameterClause)
        return .visitChildren
    }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        record(Syntax(node), name: node.name, clause: node.genericParameterClause)
        return .visitChildren
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        record(Syntax(node), name: node.name, clause: node.genericParameterClause)
        return .visitChildren
    }
}

internal final class IdiomBoundedIndexVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var valueGenericDepth: Swift::Int = 0
    let valueGenericTypes: Swift::Set<Swift::String>

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        valueGenericTypes: Swift::Set<Swift::String>
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.valueGenericTypes = valueGenericTypes
        super.init(viewMode: .sourceAccurate)
    }

    private func extendsValueGenericType(_ node: ExtensionDeclSyntax) -> Swift::Bool {
        idiomTypeNames(of: node.extendedType).contains(where: valueGenericTypes.contains)
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        if extendsValueGenericType(node) { valueGenericDepth += 1 }
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        if extendsValueGenericType(node) { valueGenericDepth -= 1 }
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if idiomHasValueGenericParameter(node.genericParameterClause) { valueGenericDepth += 1 }
        return .visitChildren
    }
    override func visitPost(_ node: StructDeclSyntax) {
        if idiomHasValueGenericParameter(node.genericParameterClause) { valueGenericDepth -= 1 }
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if idiomHasValueGenericParameter(node.genericParameterClause) { valueGenericDepth += 1 }
        return .visitChildren
    }
    override func visitPost(_ node: ClassDeclSyntax) {
        if idiomHasValueGenericParameter(node.genericParameterClause) { valueGenericDepth -= 1 }
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        if idiomHasValueGenericParameter(node.genericParameterClause) { valueGenericDepth += 1 }
        return .visitChildren
    }
    override func visitPost(_ node: ActorDeclSyntax) {
        if idiomHasValueGenericParameter(node.genericParameterClause) { valueGenericDepth -= 1 }
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        if idiomHasValueGenericParameter(node.genericParameterClause) { valueGenericDepth += 1 }
        return .visitChildren
    }
    override func visitPost(_ node: EnumDeclSyntax) {
        if idiomHasValueGenericParameter(node.genericParameterClause) { valueGenericDepth -= 1 }
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        guard valueGenericDepth > 0 else { return .visitChildren }
        for parameter in node.parameterClause.parameters {
            guard idiomIsRawIntType(parameter.type) else { continue }
            let location = converter.location(
                for: parameter.firstName.positionAfterSkippingLeadingTrivia
            )
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "bounded index static capacity",
                    message: idiomBoundedIndexMessage
                )
            )
        }
        return .visitChildren
    }
}
