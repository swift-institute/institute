internal import SwiftSyntax

internal final class MemoryExtensionNoncopyableOwnershipFinder: SyntaxVisitor {
    var found = false
    private var genericsStack: [Swift::Set<Swift::String>] = []
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }
    override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        if let attributed = node.type.as(AttributedTypeSyntax.self) {
            for specifier in attributed.specifiers {
                if let simple = specifier.as(SimpleTypeSpecifierSyntax.self) {
                    let kind = simple.specifier.tokenKind
                    if kind == .keyword(.consuming) || kind == .keyword(.borrowing) {
                        if let identifier = attributed.baseType.as(IdentifierTypeSyntax.self),
                            identifier.genericArgumentClause == nil,
                            let top = genericsStack.last,
                            top.contains(identifier.name.text)
                        {
                            return .skipChildren
                        }
                        found = true
                        return .skipChildren
                    }
                }
            }
        }
        return .visitChildren
    }
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(Self.genericNames(node.genericParameterClause))
        for modifier in node.modifiers {
            let kind = modifier.name.tokenKind
            if kind == .keyword(.consuming) || kind == .keyword(.borrowing) {
                if node.genericParameterClause == nil {
                    found = true
                    return .skipChildren
                }
                let ownGenerics = Self.genericNames(node.genericParameterClause)
                if parametersCarryTypeLevelOwnership(
                    node.signature.parameterClause.parameters,
                    excluding: ownGenerics
                ) {
                    found = true
                }
                return .skipChildren
            }
        }
        return .visitChildren
    }

    private func parametersCarryTypeLevelOwnership(
        _ parameters: FunctionParameterListSyntax,
        excluding: Swift::Set<Swift::String>
    ) -> Swift::Bool {
        for parameter in parameters {
            guard let attributed = parameter.type.as(AttributedTypeSyntax.self) else { continue }
            for specifier in attributed.specifiers {
                guard let simple = specifier.as(SimpleTypeSpecifierSyntax.self) else { continue }
                let kind = simple.specifier.tokenKind
                guard kind == .keyword(.consuming) || kind == .keyword(.borrowing) else { continue }
                if let identifier = attributed.baseType.as(IdentifierTypeSyntax.self),
                    identifier.genericArgumentClause == nil,
                    excluding.contains(identifier.name.text)
                {
                    continue
                }
                return true
            }
        }
        return false
    }
    override func visitPost(_ node: FunctionDeclSyntax) {
        if !genericsStack.isEmpty { genericsStack.removeLast() }
    }
    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(Self.genericNames(node.genericParameterClause))
        return .visitChildren
    }
    override func visitPost(_ node: InitializerDeclSyntax) {
        if !genericsStack.isEmpty { genericsStack.removeLast() }
    }
    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(Self.genericNames(node.genericParameterClause))
        return .visitChildren
    }
    override func visitPost(_ node: SubscriptDeclSyntax) {
        if !genericsStack.isEmpty { genericsStack.removeLast() }
    }
    private static func genericNames(
        _ clause: GenericParameterClauseSyntax?
    )
        -> Swift::Set<Swift::String>
    {
        guard let clause else { return [] }
        var names: Swift::Set<Swift::String> = []
        for parameter in clause.parameters {
            names.insert(parameter.name.text)
        }
        return names
    }
}
