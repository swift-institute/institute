internal import Lint
internal import SwiftSyntax

internal func structureMinimalTypeBodyFixed(
    _ source: borrowing Lint.Source.Parsed
) -> Swift::String? {
    let rewriter = StructureMinimalTypeBodyRewriter()
    let rewritten = rewriter.visit(source.tree)
    guard rewriter.changed else { return nil }
    var statements = rewritten.statements
    for extensionDecl in rewriter.pendingExtensions {
        statements.append(CodeBlockItemSyntax(item: .decl(DeclSyntax(extensionDecl))))
    }
    return rewritten.with(\.statements, statements).description
}

internal func structureMinimalTypeBodyIsFixEligible(_ node: Syntax) -> Swift::Bool {
    var current = node.parent
    while let ancestor = current {
        if ancestor.is(SourceFileSyntax.self) {
            return true
        }
        if let ext = ancestor.as(ExtensionDeclSyntax.self) {
            if structureMinimalTypeBodyHasAvailableAttribute(ext.attributes) {
                return false
            }
            current = ancestor.parent
            continue
        }
        if ancestor.is(StructDeclSyntax.self)
            || ancestor.is(ClassDeclSyntax.self)
            || ancestor.is(EnumDeclSyntax.self)
            || ancestor.is(ActorDeclSyntax.self)
            || ancestor.is(ProtocolDeclSyntax.self)
            || ancestor.is(IfConfigDeclSyntax.self)
            || ancestor.is(FunctionDeclSyntax.self)
            || ancestor.is(InitializerDeclSyntax.self)
            || ancestor.is(DeinitializerDeclSyntax.self)
            || ancestor.is(SubscriptDeclSyntax.self)
            || ancestor.is(AccessorDeclSyntax.self)
            || ancestor.is(AccessorBlockSyntax.self)
            || ancestor.is(ClosureExprSyntax.self)
        {
            return false
        }
        current = ancestor.parent
    }
    return false
}

internal func structureMinimalTypeBodyHasAvailableAttribute(
    _ attributes: AttributeListSyntax
) -> Swift::Bool {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        if attr.attributeName.trimmedDescription == "available" {
            return true
        }
    }
    return false
}

internal func structureMinimalTypeBodyEnclosingExtendedType(_ node: Syntax) -> TypeSyntax? {
    var current = node.parent
    while let ancestor = current {
        if let ext = ancestor.as(ExtensionDeclSyntax.self) {
            return ext.extendedType
        }
        if ancestor.is(SourceFileSyntax.self) { return nil }
        current = ancestor.parent
    }
    return nil
}

internal func structureMinimalTypeBodyExtendedType(
    for node: Syntax,
    ownName: TokenSyntax
) -> TypeSyntax {
    let bareName = ownName.with(\.leadingTrivia, []).with(\.trailingTrivia, [])
    guard let enclosing = structureMinimalTypeBodyEnclosingExtendedType(node) else {
        return TypeSyntax(IdentifierTypeSyntax(name: bareName))
    }
    let base = enclosing.with(\.leadingTrivia, []).with(\.trailingTrivia, [])
    return TypeSyntax(MemberTypeSyntax(baseType: base, name: bareName))
}

internal func structureMinimalTypeBodyMayMoveNestedTypeWhole(
    _ attributes: AttributeListSyntax,
    _ memberBlock: MemberBlockSyntax
) -> Swift::Bool {
    guard !structureMinimalTypeBodyHasExtensionPatternAttribute(attributes) else { return false }
    return structureMinimalTypeBodyPartition(memberBlock) == nil
}

internal func structureMinimalTypeBodyPartition(
    _ block: MemberBlockSyntax
) -> (remaining: MemberBlockItemListSyntax, moved: [MemberBlockItemSyntax])? {
    var remaining: [MemberBlockItemSyntax] = []
    var moved: [MemberBlockItemSyntax] = []

    for member in block.members {
        let decl = member.decl
        if let variable = decl.as(VariableDeclSyntax.self) {
            if structureMinimalTypeBodyIsStaticOrClassMember(variable.modifiers)
                || structureMinimalTypeBodyIsComputedProperty(variable)
            {
                moved.append(member)
            } else {
                remaining.append(member)
            }
            continue
        }
        if decl.is(FunctionDeclSyntax.self) || decl.is(SubscriptDeclSyntax.self) {
            moved.append(member)
            continue
        }
        if let typealiasDecl = decl.as(TypeAliasDeclSyntax.self) {
            if structureIsProtocolSentinelName(typealiasDecl.name.text) {
                remaining.append(member)
            } else {
                moved.append(member)
            }
            continue
        }
        if let nested = decl.as(StructDeclSyntax.self) {
            if structureMinimalTypeBodyMayMoveNestedTypeWhole(nested.attributes, nested.memberBlock) {
                moved.append(member)
            } else {
                remaining.append(member)
            }
            continue
        }
        if let nested = decl.as(ClassDeclSyntax.self) {
            if structureMinimalTypeBodyMayMoveNestedTypeWhole(nested.attributes, nested.memberBlock) {
                moved.append(member)
            } else {
                remaining.append(member)
            }
            continue
        }
        if let nested = decl.as(EnumDeclSyntax.self) {
            if structureMinimalTypeBodyMayMoveNestedTypeWhole(nested.attributes, nested.memberBlock) {
                moved.append(member)
            } else {
                remaining.append(member)
            }
            continue
        }
        if let nested = decl.as(ActorDeclSyntax.self) {
            if structureMinimalTypeBodyMayMoveNestedTypeWhole(nested.attributes, nested.memberBlock) {
                moved.append(member)
            } else {
                remaining.append(member)
            }
            continue
        }
        if decl.is(ProtocolDeclSyntax.self) {
            moved.append(member)
            continue
        }
        remaining.append(member)
    }

    guard !moved.isEmpty else { return nil }
    return (MemberBlockItemListSyntax(remaining), moved)
}

private func structureMinimalTypeBodyExtension(
    extendedType: TypeSyntax,
    members: [MemberBlockItemSyntax]
) -> ExtensionDeclSyntax {
    ExtensionDeclSyntax(
        leadingTrivia: .newlines(2),
        extensionKeyword: .keyword(.extension, trailingTrivia: .space),
        extendedType: extendedType,
        memberBlock: MemberBlockSyntax(
            leftBrace: .leftBraceToken(leadingTrivia: .space),
            members: MemberBlockItemListSyntax(members)
        )
    )
}

internal final class StructureMinimalTypeBodyRewriter: SyntaxRewriter {
    var changed: Swift::Bool = false
    var pendingExtensions: [ExtensionDeclSyntax] = []

    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        guard !structureMinimalTypeBodyIsLocal(Syntax(node)) else { return super.visit(node) }
        guard let rewritten = fixed(node: node, name: node.name, block: node.memberBlock) else {
            return super.visit(node)
        }
        changed = true
        return super.visit(node.with(\.memberBlock, rewritten))
    }

    override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
        guard !structureMinimalTypeBodyIsLocal(Syntax(node)) else { return super.visit(node) }
        guard let rewritten = fixed(node: node, name: node.name, block: node.memberBlock) else {
            return super.visit(node)
        }
        changed = true
        return super.visit(node.with(\.memberBlock, rewritten))
    }

    private func fixed(
        node: some SyntaxProtocol,
        name: TokenSyntax,
        block: MemberBlockSyntax
    ) -> MemberBlockSyntax? {
        guard structureMinimalTypeBodyIsFixEligible(Syntax(node)) else { return nil }
        guard !structureMinimalTypeBodyHasExtensionPatternAttribute(attributes(of: node)) else {
            return nil
        }
        guard !structureMinimalTypeBodyHasAvailableAttribute(attributes(of: node)) else {
            return nil
        }
        guard let (remaining, moved) = structureMinimalTypeBodyPartition(block) else { return nil }
        let extendedType = structureMinimalTypeBodyExtendedType(for: Syntax(node), ownName: name)
        pendingExtensions.append(
            structureMinimalTypeBodyExtension(extendedType: extendedType, members: moved)
        )
        return block.with(\.members, remaining)
    }

    private func attributes(of node: some SyntaxProtocol) -> AttributeListSyntax {
        if let structDecl = node.as(StructDeclSyntax.self) { return structDecl.attributes }
        if let enumDecl = node.as(EnumDeclSyntax.self) { return enumDecl.attributes }
        return AttributeListSyntax([])
    }
}
