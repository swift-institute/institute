public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `typealiased namespace bridge` = Lint.Rule(
        id: "typealiased namespace bridge",
        default: .note,
        controls: [
            .init(
                id: "typealiased namespace bridge module selector",
                source: "public typealias Span = Swift::Span",
                path: "Sources/Platform Core/Span.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "typealiased namespace bridge matching leaf",
                source: "typealias Socket = Foundation.Socket",
                path: "Sources/Platform Core/SocketBridge.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "typealiased namespace bridge different leaf",
                source: "typealias Storage = Internal.Buffer",
                path: "Sources/Platform Core/StorageAlias.swift",
                expectation: .clean
            ),
            .init(
                id: "typealiased namespace bridge conformance boundary",
                source: "extension Tagged: Collection { typealias Index = Underlying.Index }",
                path: "Sources/Platform Core/CollectionWitness.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = PlatformTypealiasedNamespaceVisitor(
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
internal let platformTypealiasedNamespaceMessage: Swift::String =
    "[typealiased namespace bridge] [PLAT-ARCH-018]: typealias whose "
    + "LHS name matches its RHS member-type leaf silently bridges a "
    + "foreign namespace into the local one. New-type declarations at "
    + "`<local>.<aliased>.<NewName>` resolve to the foreign module — "
    + "any existing type at the same foreign path conflicts silently. "
    + "Before adding sub-types via this aliased path, grep the foreign "
    + "module for collisions and choose a non-conflicting sub-path, a "
    + "non-typealiased namespace entry, or relocate the foreign type. "
    + "Surfaced as a non-counting review prompt."

internal final class PlatformTypealiasedNamespaceVisitor: SyntaxVisitor {
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

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        let aliasName = node.name.text
        let targetLeaf: Swift::String? =
            if let member = node.initializer.value.as(MemberTypeSyntax.self) {
                member.name.text
            } else if let identifier = node.initializer.value.as(IdentifierTypeSyntax.self),
                identifier.moduleSelector != nil
            {
                identifier.name.text
            } else {
                nil
            }
        guard targetLeaf == aliasName else { return .visitChildren }
        if isInsideConformingExtension(Syntax(node)) {
            return .visitChildren
        }
        let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "typealiased namespace bridge",
                message: platformTypealiasedNamespaceMessage
            )
        )
        return .visitChildren
    }

    private func isInsideConformingExtension(_ node: Syntax) -> Swift::Bool {
        var current: Syntax? = node.parent
        var immediateExtension: ExtensionDeclSyntax? = nil
        while let candidate = current {
            if let ext = candidate.as(ExtensionDeclSyntax.self) {
                immediateExtension = ext
                break
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
            if candidate.is(ProtocolDeclSyntax.self) {
                return true
            }
            current = candidate.parent
        }
        guard let ext = immediateExtension else { return false }
        if ext.inheritanceClause != nil { return true }

        return fileDeclaresConformance(
            forExtendedType: ext.extendedType.trimmedDescription,
            origin: node
        )
    }

    private func fileDeclaresConformance(
        forExtendedType targetPath: Swift::String,
        origin: Syntax
    ) -> Swift::Bool {
        var current: Syntax? = origin
        while let candidate = current {
            if let file = candidate.as(SourceFileSyntax.self) {
                for statement in Lint.Syntax.Conditional.statements(file.statements) {
                    if Self.declConformsToProtocol(
                        statement.item,
                        targetPath: targetPath,
                        currentPrefix: ""
                    ) {
                        return true
                    }
                }
                return false
            }
            current = candidate.parent
        }
        return false
    }

    private static func declConformsToProtocol(
        _ item: CodeBlockItemSyntax.Item,
        targetPath: Swift::String,
        currentPrefix: Swift::String
    ) -> Swift::Bool {
        if let ext = item.as(ExtensionDeclSyntax.self) {
            let extendedType = ext.extendedType.trimmedDescription
            let fullPath: Swift::String =
                currentPrefix.isEmpty
                ? extendedType
                : currentPrefix + "." + extendedType
            if fullPath == targetPath, ext.inheritanceClause != nil {
                return true
            }
            for member in Lint.Syntax.Conditional.members(ext.memberBlock) {
                if Self.memberConformsToProtocol(
                    member.decl,
                    targetPath: targetPath,
                    currentPrefix: fullPath
                ) {
                    return true
                }
            }
            return false
        }
        if let structDecl = item.as(StructDeclSyntax.self) {
            return Self.typeDeclConformsToProtocol(
                name: structDecl.name.text,
                inheritanceClause: structDecl.inheritanceClause,
                memberBlock: structDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix
            )
        }
        if let classDecl = item.as(ClassDeclSyntax.self) {
            return Self.typeDeclConformsToProtocol(
                name: classDecl.name.text,
                inheritanceClause: classDecl.inheritanceClause,
                memberBlock: classDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix
            )
        }
        if let enumDecl = item.as(EnumDeclSyntax.self) {
            return Self.typeDeclConformsToProtocol(
                name: enumDecl.name.text,
                inheritanceClause: enumDecl.inheritanceClause,
                memberBlock: enumDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix
            )
        }
        if let actorDecl = item.as(ActorDeclSyntax.self) {
            return Self.typeDeclConformsToProtocol(
                name: actorDecl.name.text,
                inheritanceClause: actorDecl.inheritanceClause,
                memberBlock: actorDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix
            )
        }
        return false
    }

    private static func memberConformsToProtocol(
        _ decl: DeclSyntax,
        targetPath: Swift::String,
        currentPrefix: Swift::String
    ) -> Swift::Bool {
        if let structDecl = decl.as(StructDeclSyntax.self) {
            return Self.typeDeclConformsToProtocol(
                name: structDecl.name.text,
                inheritanceClause: structDecl.inheritanceClause,
                memberBlock: structDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix
            )
        }
        if let classDecl = decl.as(ClassDeclSyntax.self) {
            return Self.typeDeclConformsToProtocol(
                name: classDecl.name.text,
                inheritanceClause: classDecl.inheritanceClause,
                memberBlock: classDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix
            )
        }
        if let enumDecl = decl.as(EnumDeclSyntax.self) {
            return Self.typeDeclConformsToProtocol(
                name: enumDecl.name.text,
                inheritanceClause: enumDecl.inheritanceClause,
                memberBlock: enumDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix
            )
        }
        if let actorDecl = decl.as(ActorDeclSyntax.self) {
            return Self.typeDeclConformsToProtocol(
                name: actorDecl.name.text,
                inheritanceClause: actorDecl.inheritanceClause,
                memberBlock: actorDecl.memberBlock,
                targetPath: targetPath,
                currentPrefix: currentPrefix
            )
        }
        return false
    }

    private static func typeDeclConformsToProtocol(
        name: Swift::String,
        inheritanceClause: InheritanceClauseSyntax?,
        memberBlock: MemberBlockSyntax,
        targetPath: Swift::String,
        currentPrefix: Swift::String
    ) -> Swift::Bool {
        let fullPath: Swift::String =
            currentPrefix.isEmpty
            ? name
            : currentPrefix + "." + name
        if fullPath == targetPath, inheritanceClause != nil {
            return true
        }
        for member in Lint.Syntax.Conditional.members(memberBlock) {
            if Self.memberConformsToProtocol(
                member.decl,
                targetPath: targetPath,
                currentPrefix: fullPath
            ) {
                return true
            }
        }
        return false
    }
}
