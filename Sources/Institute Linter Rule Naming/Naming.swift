internal import SwiftSyntax

internal enum Naming {}

extension Naming {
    internal static func isInsideExtensionPattern(_ node: Syntax) -> Bool {
        var current: Syntax? = node.parent
        while let candidate = current {
            if let typeDecl = candidate.as(StructDeclSyntax.self) {
                return hasExtensionPattern(typeDecl.attributes)
            }
            if let typeDecl = candidate.as(EnumDeclSyntax.self) {
                return hasExtensionPattern(typeDecl.attributes)
            }
            if let typeDecl = candidate.as(ClassDeclSyntax.self) {
                return hasExtensionPattern(typeDecl.attributes)
            }
            if let typeDecl = candidate.as(ActorDeclSyntax.self) {
                return hasExtensionPattern(typeDecl.attributes)
            }
            current = candidate.parent
        }
        return false
    }

    internal static func hasExtensionPattern(_ attributes: AttributeListSyntax) -> Bool {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            let name = attr.attributeName.trimmedDescription
            if name == "resultBuilder" || name == "Suite" {
                return true
            }
        }
        return false
    }

    internal static func hasAttribute(
        _ attributes: AttributeListSyntax,
        named name: Swift::String
    ) -> Swift::Bool {
        for attribute in attributes {
            guard case .attribute(let attr) = attribute else { continue }
            let attributeName = attr.attributeName.trimmedDescription
            if attributeName == name || attributeName.hasSuffix(".\(name)") {
                return true
            }
        }
        return false
    }

    internal static func isTestScaffolding(_ node: Syntax, attributes: AttributeListSyntax) -> Bool {
        if hasAttribute(attributes, named: "Test") || hasAttribute(attributes, named: "Suite") {
            return true
        }
        var current: Syntax? = node.parent
        while let candidate = current {
            if let decl = candidate.as(StructDeclSyntax.self),
                hasAttribute(decl.attributes, named: "Suite")
            {
                return true
            }
            if let decl = candidate.as(ClassDeclSyntax.self),
                hasAttribute(decl.attributes, named: "Suite")
            {
                return true
            }
            if let decl = candidate.as(EnumDeclSyntax.self),
                hasAttribute(decl.attributes, named: "Suite")
            {
                return true
            }
            if let decl = candidate.as(ActorDeclSyntax.self),
                hasAttribute(decl.attributes, named: "Suite")
            {
                return true
            }
            if let ext = candidate.as(ExtensionDeclSyntax.self) {
                if let leaf = extendedTypeLeafName(ext.extendedType),
                    suiteTypeNames(in: ext.root).contains(leaf)
                {
                    return true
                }
            }
            current = candidate.parent
        }
        return false
    }

    private static func extendedTypeLeafName(_ type: TypeSyntax) -> Swift::String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return member.name.text
        }
        return nil
    }

    private static func suiteTypeNames(in root: Syntax) -> Swift::Set<Swift::String> {
        var names: Swift::Set<Swift::String> = []
        func collect(_ node: Syntax) {
            if let decl = node.as(StructDeclSyntax.self),
                hasAttribute(decl.attributes, named: "Suite")
            {
                names.insert(decl.name.text)
            } else if let decl = node.as(ClassDeclSyntax.self),
                hasAttribute(decl.attributes, named: "Suite")
            {
                names.insert(decl.name.text)
            } else if let decl = node.as(EnumDeclSyntax.self),
                hasAttribute(decl.attributes, named: "Suite")
            {
                names.insert(decl.name.text)
            } else if let decl = node.as(ActorDeclSyntax.self),
                hasAttribute(decl.attributes, named: "Suite")
            {
                names.insert(decl.name.text)
            }
            for child in node.children(viewMode: .sourceAccurate) { collect(child) }
        }
        collect(root)
        return names
    }

    internal static func isInsideConformingContext(_ node: Syntax) -> Bool {
        var current: Syntax? = node.parent
        while let candidate = current {
            if let ext = candidate.as(ExtensionDeclSyntax.self) {
                return ext.inheritanceClause != nil
            }
            if let typeDecl = candidate.as(StructDeclSyntax.self) {
                return typeDecl.inheritanceClause != nil
            }
            if let typeDecl = candidate.as(ClassDeclSyntax.self) {
                return typeDecl.inheritanceClause != nil
            }
            if let typeDecl = candidate.as(EnumDeclSyntax.self) {
                return typeDecl.inheritanceClause != nil
            }
            if let typeDecl = candidate.as(ActorDeclSyntax.self) {
                return typeDecl.inheritanceClause != nil
            }
            current = candidate.parent
        }
        return false
    }

    internal static func conformances(_ node: Syntax) -> [Swift::String] {
        var current: Syntax? = node.parent
        var immediateExtension: ExtensionDeclSyntax? = nil
        while let candidate = current {
            if let ext = candidate.as(ExtensionDeclSyntax.self) {
                immediateExtension = ext
                break
            }
            if let typeDecl = candidate.as(StructDeclSyntax.self) {
                return Visitor.inheritanceLeaves(typeDecl.inheritanceClause)
            }
            if let typeDecl = candidate.as(ClassDeclSyntax.self) {
                return Visitor.inheritanceLeaves(typeDecl.inheritanceClause)
            }
            if let typeDecl = candidate.as(EnumDeclSyntax.self) {
                return Visitor.inheritanceLeaves(typeDecl.inheritanceClause)
            }
            if let typeDecl = candidate.as(ActorDeclSyntax.self) {
                return Visitor.inheritanceLeaves(typeDecl.inheritanceClause)
            }
            if let protocolDecl = candidate.as(ProtocolDeclSyntax.self) {
                return [protocolDecl.name.text]
            }
            current = candidate.parent
        }
        guard let ext = immediateExtension else { return [] }
        let leaves = Visitor.inheritanceLeaves(ext.inheritanceClause)
        if !leaves.isEmpty {
            return leaves
        }
        return Self.fileScopeConformances(
            for: ext.extendedType.trimmedDescription,
            origin: node
        )
    }

    fileprivate static func fileScopeConformances(
        for targetPath: Swift::String,
        origin: Syntax
    ) -> [Swift::String] {
        var current: Syntax? = origin
        while let candidate = current {
            if let file = candidate.as(SourceFileSyntax.self) {
                var collected: [Swift::String] = []
                for statement in file.statements {
                    Self.collectConformances(
                        from: statement.item,
                        targetPath: targetPath,
                        currentPrefix: "",
                        into: &collected
                    )
                }
                return collected
            }
            current = candidate.parent
        }
        return []
    }

    fileprivate static func collectConformances(
        from item: CodeBlockItemSyntax.Item,
        targetPath: Swift::String,
        currentPrefix: Swift::String,
        into collected: inout [Swift::String]
    ) {
        if let ext = item.as(ExtensionDeclSyntax.self) {
            let extendedType = ext.extendedType.trimmedDescription
            let fullPath =
                currentPrefix.isEmpty
                ? extendedType
                : currentPrefix + "." + extendedType
            if fullPath == targetPath {
                collected.append(contentsOf: Visitor.inheritanceLeaves(ext.inheritanceClause))
            }
            for member in ext.memberBlock.members {
                Self.collectConformancesFromDecl(
                    member.decl,
                    targetPath: targetPath,
                    currentPrefix: fullPath,
                    into: &collected
                )
            }
            return
        }
        if let structDecl = item.as(StructDeclSyntax.self) {
            Self.collectFromTypeDecl(
                name: structDecl.name.text,
                inheritanceClause: structDecl.inheritanceClause,
                memberBlock: structDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix,
                into: &collected
            )
            return
        }
        if let classDecl = item.as(ClassDeclSyntax.self) {
            Self.collectFromTypeDecl(
                name: classDecl.name.text,
                inheritanceClause: classDecl.inheritanceClause,
                memberBlock: classDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix,
                into: &collected
            )
            return
        }
        if let enumDecl = item.as(EnumDeclSyntax.self) {
            Self.collectFromTypeDecl(
                name: enumDecl.name.text,
                inheritanceClause: enumDecl.inheritanceClause,
                memberBlock: enumDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix,
                into: &collected
            )
            return
        }
        if let actorDecl = item.as(ActorDeclSyntax.self) {
            Self.collectFromTypeDecl(
                name: actorDecl.name.text,
                inheritanceClause: actorDecl.inheritanceClause,
                memberBlock: actorDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix,
                into: &collected
            )
            return
        }
    }

    fileprivate static func collectConformancesFromDecl(
        _ decl: DeclSyntax,
        targetPath: Swift::String,
        currentPrefix: Swift::String,
        into collected: inout [Swift::String]
    ) {
        if let structDecl = decl.as(StructDeclSyntax.self) {
            Self.collectFromTypeDecl(
                name: structDecl.name.text,
                inheritanceClause: structDecl.inheritanceClause,
                memberBlock: structDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix,
                into: &collected
            )
            return
        }
        if let classDecl = decl.as(ClassDeclSyntax.self) {
            Self.collectFromTypeDecl(
                name: classDecl.name.text,
                inheritanceClause: classDecl.inheritanceClause,
                memberBlock: classDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix,
                into: &collected
            )
            return
        }
        if let enumDecl = decl.as(EnumDeclSyntax.self) {
            Self.collectFromTypeDecl(
                name: enumDecl.name.text,
                inheritanceClause: enumDecl.inheritanceClause,
                memberBlock: enumDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix,
                into: &collected
            )
            return
        }
        if let actorDecl = decl.as(ActorDeclSyntax.self) {
            Self.collectFromTypeDecl(
                name: actorDecl.name.text,
                inheritanceClause: actorDecl.inheritanceClause,
                memberBlock: actorDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix,
                into: &collected
            )
            return
        }
    }

    fileprivate static func collectFromTypeDecl(
        name: Swift::String,
        inheritanceClause: InheritanceClauseSyntax?,
        memberBlock: MemberBlockSyntax,
        targetPath: Swift::String,
        currentPrefix: Swift::String,
        into collected: inout [Swift::String]
    ) {
        let fullPath =
            currentPrefix.isEmpty
            ? name
            : currentPrefix + "." + name
        if fullPath == targetPath {
            collected.append(contentsOf: Visitor.inheritanceLeaves(inheritanceClause))
        }
        for member in memberBlock.members {
            Self.collectConformancesFromDecl(
                member.decl,
                targetPath: targetPath,
                currentPrefix: fullPath,
                into: &collected
            )
        }
    }

    internal static func isProtocolSentinel(_ name: Swift::String) -> Swift::Bool {
        return name == "Protocol" || name == "`Protocol`"
    }

    internal static func hasFileprivateOrPrivate(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            let kind = modifier.name.tokenKind
            if kind == .keyword(.fileprivate) || kind == .keyword(.private) {
                return true
            }
        }
        return false
    }

    internal static func hasFileprivateOrPrivateEffective(
        _ node: Syntax,
        modifiers: DeclModifierListSyntax
    ) -> Bool {
        if hasFileprivateOrPrivate(modifiers) {
            return true
        }
        var current: Syntax? = node.parent
        while let candidate = current {
            if let typeDecl = candidate.as(StructDeclSyntax.self) {
                if hasFileprivateOrPrivate(typeDecl.modifiers) { return true }
            } else if let typeDecl = candidate.as(ClassDeclSyntax.self) {
                if hasFileprivateOrPrivate(typeDecl.modifiers) { return true }
            } else if let typeDecl = candidate.as(EnumDeclSyntax.self) {
                if hasFileprivateOrPrivate(typeDecl.modifiers) { return true }
            } else if let typeDecl = candidate.as(ActorDeclSyntax.self) {
                if hasFileprivateOrPrivate(typeDecl.modifiers) { return true }
            } else if let ext = candidate.as(ExtensionDeclSyntax.self) {
                if hasFileprivateOrPrivate(ext.modifiers) { return true }
                if extendsFilePrivateType(ext) { return true }
            }
            current = candidate.parent
        }
        return false
    }

    private static func extendsFilePrivateType(_ ext: ExtensionDeclSyntax) -> Bool {
        guard let root = extendedTypeRootName(ext.extendedType) else { return false }
        return filePrivateTypeNames(in: ext.root).contains(root)
    }

    private static func extendedTypeRootName(_ type: TypeSyntax) -> Swift::String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return extendedTypeRootName(member.baseType)
        }
        return nil
    }

    private static func filePrivateTypeNames(in root: Syntax) -> Swift::Set<Swift::String> {
        var names: Swift::Set<Swift::String> = []
        func collect(_ node: Syntax) {
            if let decl = node.as(StructDeclSyntax.self), hasFileprivateOrPrivate(decl.modifiers) {
                names.insert(decl.name.text)
            } else if let decl = node.as(ClassDeclSyntax.self),
                hasFileprivateOrPrivate(decl.modifiers)
            {
                names.insert(decl.name.text)
            } else if let decl = node.as(EnumDeclSyntax.self),
                hasFileprivateOrPrivate(decl.modifiers)
            {
                names.insert(decl.name.text)
            } else if let decl = node.as(ActorDeclSyntax.self),
                hasFileprivateOrPrivate(decl.modifiers)
            {
                names.insert(decl.name.text)
            }
            for child in node.children(viewMode: .sourceAccurate) { collect(child) }
        }
        collect(root)
        return names
    }

    internal static func hasPublicOrOpen(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            let kind = modifier.name.tokenKind
            if kind == .keyword(.public) || kind == .keyword(.open) {
                return true
            }
        }
        return false
    }

    internal static func hasPublicOrOpenEffective(
        _ node: Syntax,
        modifiers: DeclModifierListSyntax
    ) -> Bool {
        if hasPublicOrOpen(modifiers) {
            return true
        }
        var current: Syntax? = node.parent
        while let candidate = current {
            if let ext = candidate.as(ExtensionDeclSyntax.self) {
                return hasPublicOrOpen(ext.modifiers)
            }
            current = candidate.parent
        }
        return false
    }
}

extension Naming {
    @inlinable
    package static func isBackticked(_ token: TokenSyntax) -> Swift::Bool {
        token.trimmedDescription.hasPrefix("`")
    }
}

internal func namingIsShorthandGetterAccessorBlock(_ node: Syntax) -> Swift::Bool {
    guard let block = node.as(AccessorBlockSyntax.self) else { return false }
    if case .getter = block.accessors { return true }
    return false
}

internal func namingHasStoredInstanceProperty(_ block: MemberBlockSyntax) -> Swift::Bool {
    for member in block.members {
        guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
        if variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) {
            continue
        }
        for binding in variable.bindings {
            if binding.accessorBlock == nil { return true }
        }
    }
    return false
}

internal func namingHasEnumCase(_ block: MemberBlockSyntax) -> Swift::Bool {
    for member in block.members where member.decl.is(EnumCaseDeclSyntax.self) { return true }
    return false
}

internal func namingIsPackageManifest(_ filePath: Swift::String) -> Swift::Bool {
    guard let filename = filePath.split(separator: "/", omittingEmptySubsequences: true).last
    else { return false }
    if filename == "Package.swift" { return true }
    return filename.hasPrefix("Package@swift-") && filename.hasSuffix(".swift")
}
