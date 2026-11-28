internal import SwiftSyntax

extension ManifestSourceFacts {
    /// Walks one file's declarations and records what `ManifestSourceFacts` reads.
    internal struct Walker {
        var empty = true
        var declarations: [ManifestSourceFacts.Declaration] = []
    }
}

extension ManifestSourceFacts.Walker {
    mutating func statements(_ list: CodeBlockItemListSyntax, scope: ManifestSourceFacts.Scope) {
        for statement in list {
            guard let declaration = statement.item.as(DeclSyntax.self) else {
                empty = false
                continue
            }
            self.declaration(declaration, scope: scope)
        }
    }

    mutating func members(_ list: MemberBlockItemListSyntax, scope: ManifestSourceFacts.Scope) {
        for member in list {
            declaration(member.decl, scope: scope)
        }
    }

    mutating func declaration(_ declaration: DeclSyntax, scope: ManifestSourceFacts.Scope) {
        if declaration.is(ImportDeclSyntax.self) { return }
        if let conditional = declaration.as(IfConfigDeclSyntax.self) {
            var previous: [Swift::String] = []
            for clause in conditional.clauses {
                var inner = scope
                let condition = clause.condition.map(manifestNormalized)
                inner.conditions += previous.map { "!(\($0))" } + (condition.map { [$0] } ?? [])
                if let condition { previous.append(condition) }
                switch clause.elements {
                case .statements(let list)?: statements(list, scope: inner)
                case .decls(let list)?: members(list, scope: inner)
                case nil: break
                default: empty = false
                }
            }
            return
        }
        if let node = declaration.as(ExtensionDeclSyntax.self) {
            if node.inheritanceClause != nil { empty = false }
            var inner = scope
            inner.path = manifestTypePath(node.extendedType.trimmedDescription)
            if let requirements = node.genericWhereClause {
                inner.requirements.append(manifestNormalized(requirements.requirements))
            }
            inner.publicByDefault = manifestIsPublic(node.modifiers)
            members(node.memberBlock.members, scope: inner)
            return
        }
        if let node = declaration.as(EnumDeclSyntax.self) {
            let namespace =
                node.inheritanceClause == nil && node.genericParameterClause == nil
                && node.memberBlock.members.isEmpty
            if !namespace { empty = false }
            nominal(node.name, node.modifiers, node.memberBlock, scope: scope)
            return
        }
        if let node = declaration.as(StructDeclSyntax.self) {
            empty = false
            nominal(node.name, node.modifiers, node.memberBlock, scope: scope)
            return
        }
        if let node = declaration.as(ClassDeclSyntax.self) {
            empty = false
            nominal(node.name, node.modifiers, node.memberBlock, scope: scope)
            return
        }
        if let node = declaration.as(ActorDeclSyntax.self) {
            empty = false
            nominal(node.name, node.modifiers, node.memberBlock, scope: scope)
            return
        }
        if let node = declaration.as(ProtocolDeclSyntax.self) {
            empty = false
            nominal(node.name, node.modifiers, node.memberBlock, scope: scope)
            return
        }
        empty = false
        if let node = declaration.as(TypeAliasDeclSyntax.self) {
            record(node.name, node.modifiers, kind: .alias, scope: scope)
        } else if let node = declaration.as(MacroDeclSyntax.self) {
            record(node.name, node.modifiers, kind: .macro, scope: scope)
        }
    }

    private mutating func nominal(
        _ name: TokenSyntax,
        _ modifiers: DeclModifierListSyntax,
        _ block: MemberBlockSyntax,
        scope: ManifestSourceFacts.Scope
    ) {
        record(name, modifiers, kind: .type, scope: scope)
        var inner = scope
        inner.path.append(manifestUnescaped(name.text))
        inner.publicByDefault = false
        members(block.members, scope: inner)
    }

    private mutating func record(
        _ name: TokenSyntax,
        _ modifiers: DeclModifierListSyntax,
        kind: ManifestSourceFacts.Declaration.Kind,
        scope: ManifestSourceFacts.Scope
    ) {
        let path = scope.path + [manifestUnescaped(name.text)]
        let explicit = modifiers.contains { modifier in
            [.keyword(.public), .keyword(.open), .keyword(.internal), .keyword(.private), .keyword(.fileprivate), .keyword(.package)]
                .contains(modifier.name.tokenKind)
        }
        let isPublic = manifestIsPublic(modifiers) || (!explicit && scope.publicByDefault)
        declarations.append(
            .init(
                path: path,
                key: path.joined(separator: ".") + " where " + scope.requirements.joined(separator: ", ")
                    + " if " + scope.conditions.joined(separator: " && "),
                kind: kind,
                isPublic: isPublic,
                position: name.positionAfterSkippingLeadingTrivia
            )
        )
    }
}

private func manifestIsPublic(_ modifiers: DeclModifierListSyntax) -> Swift::Bool {
    modifiers.contains { $0.name.tokenKind == .keyword(.public) || $0.name.tokenKind == .keyword(.open) }
}

private func manifestNormalized(_ node: some SyntaxProtocol) -> Swift::String {
    node.trimmedDescription.split(whereSeparator: \.isWhitespace).joined(separator: " ")
}

private func manifestUnescaped(_ text: Swift::String) -> Swift::String {
    text.filter { $0 != "`" }
}

/// The components of a written type, without generic arguments or backticks: `Foo<T>.Bar` gives `Foo` and `Bar`.
internal func manifestTypePath(_ written: Swift::String) -> [Swift::String] {
    var depth = 0
    var stripped = ""
    for character in written {
        if character == "<" { depth += 1 } else if character == ">" { depth -= 1 } else if depth == 0 { stripped.append(character) }
    }
    return stripped.split(separator: ".").map { $0.filter { $0 != "`" && !$0.isWhitespace } }
}
