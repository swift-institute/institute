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

/// The `where` clause an extension needs to keep members available for every generic argument the type itself
/// admits: a parameter declared `T: ~Copyable` (or `~Escapable`, or so suppressed in the type's `where` clause) is
/// implicitly `Copyable` again in a plain `extension`, so moved members would stop applying to noncopyable arguments.
internal func structureMinimalTypeBodySuppressionWhereClause(
    _ generics: GenericParameterClauseSyntax?,
    _ whereClause: GenericWhereClauseSyntax?
) -> GenericWhereClauseSyntax? {
    guard let generics else { return nil }
    var requirements: [GenericRequirementSyntax] = []
    for parameter in generics.parameters {
        let name = parameter.name.text
        let declared = parameter.inheritedType.map { $0.trimmedDescription } ?? ""
        var inWhere = ""
        if let whereClause {
            for requirement in whereClause.requirements {
                if case .conformanceRequirement(let conformance) = requirement.requirement,
                    conformance.leftType.trimmedDescription == name
                {
                    inWhere += " " + conformance.rightType.trimmedDescription
                }
            }
        }
        let suppressed = ["Copyable", "Escapable"].filter { declared.contains("~" + $0) || inWhere.contains("~" + $0) }
        guard !suppressed.isEmpty else { continue }
        let types = suppressed.map {
            TypeSyntax(SuppressedTypeSyntax(withoutTilde: .prefixOperator("~"), type: IdentifierTypeSyntax(name: .identifier($0))))
        }
        let right: TypeSyntax =
            if types.count == 1 {
                types[0]
            } else {
                TypeSyntax(
                    CompositionTypeSyntax(
                        elements: CompositionTypeElementListSyntax(
                            types.enumerated().map { index, type in
                                let last = index == types.indices.last
                                return CompositionTypeElementSyntax(
                                    type: type.with(\.trailingTrivia, last ? [] : .space),
                                    ampersand: last ? nil : .binaryOperator("&", trailingTrivia: .space)
                                )
                            }
                        )
                    )
                )
            }
        requirements.append(
            GenericRequirementSyntax(
                requirement: .conformanceRequirement(
                    ConformanceRequirementSyntax(
                        leftType: IdentifierTypeSyntax(name: .identifier(name)),
                        colon: .colonToken(trailingTrivia: .space),
                        rightType: right
                    )
                )
            )
        )
    }
    guard !requirements.isEmpty else { return nil }
    let list = requirements.enumerated().map { index, requirement in
        requirement.with(\.trailingComma, index == requirements.indices.last ? nil : .commaToken(trailingTrivia: .space))
    }
    return GenericWhereClauseSyntax(
        leadingTrivia: .space,
        whereKeyword: .keyword(.where, trailingTrivia: .space),
        requirements: GenericRequirementListSyntax(list)
    )
}

/// Whether the moved members name something by a bare capitalised identifier the type itself doesn't declare.
/// Moved out of `extension Outer { struct Inner { ... } }` into `extension Outer.Inner`, such a name is no longer
/// looked up in `Outer`, so `Outer`'s other members (declared in this file or any other) stop resolving. The fix
/// can't tell those from module-level names, so inside an extension it moves only members that name nothing else.
internal func structureMinimalTypeBodyNamesOutsideType(
    _ moved: [MemberBlockItemSyntax],
    ownName: Swift::String,
    block: MemberBlockSyntax,
    generics: GenericParameterClauseSyntax?
) -> Swift::Bool {
    var allowed: Swift::Set<Swift::String> = [ownName, "Self"]
    for parameter in generics?.parameters ?? [] { allowed.insert(parameter.name.text) }
    for member in block.members {
        let decl = member.decl
        if let d = decl.as(StructDeclSyntax.self) { allowed.insert(d.name.text) }
        if let d = decl.as(EnumDeclSyntax.self) { allowed.insert(d.name.text) }
        if let d = decl.as(ClassDeclSyntax.self) { allowed.insert(d.name.text) }
        if let d = decl.as(ActorDeclSyntax.self) { allowed.insert(d.name.text) }
        if let d = decl.as(TypeAliasDeclSyntax.self) { allowed.insert(d.name.text) }
        if let d = decl.as(ProtocolDeclSyntax.self) { allowed.insert(d.name.text) }
    }
    final class Names: SyntaxVisitor {
        var names: Swift::Set<Swift::String> = []
        override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
            names.insert(node.name.text)
            return .visitChildren
        }
        override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
            if node.parent?.as(MemberAccessExprSyntax.self)?.declName.id != node.id {
                names.insert(node.baseName.text)
            }
            return .visitChildren
        }
    }
    let visitor = Names(viewMode: .sourceAccurate)
    for member in moved { visitor.walk(member) }
    for name in visitor.names {
        let bare = Swift::String(name.filter { $0 != "`" })
        guard let first = bare.first, first.isUppercase else { continue }
        if !allowed.contains(name) && !allowed.contains(bare) { return true }
    }
    return false
}

private func structureMinimalTypeBodyExtension(
    extendedType: TypeSyntax,
    whereClause: GenericWhereClauseSyntax? = nil,
    members: [MemberBlockItemSyntax]
) -> ExtensionDeclSyntax {
    ExtensionDeclSyntax(
        leadingTrivia: .newlines(2),
        extensionKeyword: .keyword(.extension, trailingTrivia: .space),
        extendedType: extendedType,
        genericWhereClause: whereClause,
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
        let generics = genericParameters(of: node)
        if structureMinimalTypeBodyEnclosingExtendedType(Syntax(node)) != nil,
            structureMinimalTypeBodyNamesOutsideType(moved, ownName: name.text, block: block, generics: generics)
        {
            return nil
        }
        let extendedType = structureMinimalTypeBodyExtendedType(for: Syntax(node), ownName: name)
        pendingExtensions.append(
            structureMinimalTypeBodyExtension(
                extendedType: extendedType,
                whereClause: structureMinimalTypeBodySuppressionWhereClause(generics, whereClause(of: node)),
                members: moved
            )
        )
        return block.with(\.members, remaining)
    }

    private func genericParameters(of node: some SyntaxProtocol) -> GenericParameterClauseSyntax? {
        if let structDecl = node.as(StructDeclSyntax.self) { return structDecl.genericParameterClause }
        if let enumDecl = node.as(EnumDeclSyntax.self) { return enumDecl.genericParameterClause }
        return nil
    }

    private func whereClause(of node: some SyntaxProtocol) -> GenericWhereClauseSyntax? {
        if let structDecl = node.as(StructDeclSyntax.self) { return structDecl.genericWhereClause }
        if let enumDecl = node.as(EnumDeclSyntax.self) { return enumDecl.genericWhereClause }
        return nil
    }

    private func attributes(of node: some SyntaxProtocol) -> AttributeListSyntax {
        if let structDecl = node.as(StructDeclSyntax.self) { return structDecl.attributes }
        if let enumDecl = node.as(EnumDeclSyntax.self) { return enumDecl.attributes }
        return AttributeListSyntax([])
    }
}
