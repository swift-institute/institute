internal import Lint
internal import SwiftSyntax

internal func platformSwiftQualificationFixed(
    _ source: borrowing Lint.Source.Parsed
) -> Swift::String? {
    let rewriter = PlatformSwiftQualificationRewriter(
        declared: platformSwiftQualificationDeclaredShadowNames(in: source.tree)
    )
    let rewritten = rewriter.visit(source.tree)
    guard rewriter.changed else { return nil }
    return rewritten.description
}

internal func platformSwiftQualificationDeclaredShadowNames(
    in tree: SourceFileSyntax
) -> Swift::Set<Swift::String> {
    let collector = PlatformSwiftQualificationShadowDeclarationCollector()
    collector.walk(tree)
    return collector.declared
}

private final class PlatformSwiftQualificationShadowDeclarationCollector: SyntaxVisitor {
    var declared: Swift::Set<Swift::String> = []

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    private func record(_ name: TokenSyntax) {
        guard platformSwiftQualificationShadowedProtocols.contains(name.text) else { return }
        declared.insert(name.text)
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name)
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name)
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name)
        return .visitChildren
    }

    override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name)
        return .visitChildren
    }

    override func visit(_ node: GenericParameterSyntax) -> SyntaxVisitorContinueKind {
        record(node.name)
        return .visitChildren
    }
}

internal func platformSwiftQualificationQualified(
    _ type: TypeSyntax,
    declared: Swift::Set<Swift::String> = []
) -> TypeSyntax? {
    if let optional = type.as(OptionalTypeSyntax.self) {
        guard
            let inner = platformSwiftQualificationQualified(
                optional.wrappedType,
                declared: declared
            )
        else { return nil }
        return TypeSyntax(optional.with(\.wrappedType, inner))
    }
    if let iuo = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        guard let inner = platformSwiftQualificationQualified(iuo.wrappedType, declared: declared)
        else { return nil }
        return TypeSyntax(iuo.with(\.wrappedType, inner))
    }
    if let attributed = type.as(AttributedTypeSyntax.self) {
        guard
            let inner = platformSwiftQualificationQualified(attributed.baseType, declared: declared)
        else { return nil }
        return TypeSyntax(attributed.with(\.baseType, inner))
    }
    if let composition = type.as(CompositionTypeSyntax.self) {
        var elements = composition.elements
        var changed = false
        for index in elements.indices {
            guard
                let inner = platformSwiftQualificationQualified(
                    elements[index].type,
                    declared: declared
                )
            else { continue }
            elements[index] = elements[index].with(\.type, inner)
            changed = true
        }
        guard changed else { return nil }
        return TypeSyntax(composition.with(\.elements, elements))
    }
    if let someAny = type.as(SomeOrAnyTypeSyntax.self) {
        guard
            let inner = platformSwiftQualificationQualified(someAny.constraint, declared: declared)
        else { return nil }
        return TypeSyntax(someAny.with(\.constraint, inner))
    }
    guard let identifier = type.as(IdentifierTypeSyntax.self),
        platformSwiftQualificationShadowedProtocols.contains(identifier.name.text),
        !declared.contains(identifier.name.text)
    else {
        return nil
    }
    let base = IdentifierTypeSyntax(
        name: .identifier("Swift", leadingTrivia: identifier.leadingTrivia)
    )
    let member = MemberTypeSyntax(
        baseType: TypeSyntax(base),
        name: identifier.name.with(\.leadingTrivia, []),
        genericArgumentClause: identifier.genericArgumentClause
    )
    return TypeSyntax(member)
}
