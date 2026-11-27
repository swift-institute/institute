public import Institute_Model
internal import SwiftParser
internal import SwiftSyntax

extension Institute.Inventory {
    /// Reads one Swift source file into `Facts`, by syntax alone.
    ///
    /// Types are named by their dotted path, resolved through syntactic
    /// nesting and through the extended type of an enclosing extension.
    /// Types declared inside a function, accessor or closure body are local
    /// and left out. Every `#if` clause is read.
    public enum Walker {
        public static func facts(source: Swift.String) -> Facts {
            let tree = Parser.parse(source: source)
            let visitor = Visitor(tree: tree)
            visitor.walk(tree)
            var facts = visitor.facts
            facts.lines = Self.lines(source)
            return facts
        }

        static func lines(_ source: Swift.String) -> Swift.Int {
            var count = 0
            var last: Swift.UInt8 = 0x0A
            for byte in source.utf8 {
                if byte == 0x0A { count += 1 }
                last = byte
            }
            return last == 0x0A ? count : count + 1
        }
    }
}

extension Institute.Inventory.Walker {
    /// One enclosing scope: a type body, an extension body, or a
    /// declaration that only brings generic parameters into scope.
    struct Scope {
        enum Kind { case type, `extension`, generics }
        var kind: Kind
        var path: [Swift.String]
        var generics: [Swift.String]
        var moduleSelector: Swift.String
        var access: Swift.String
    }

    final class Visitor: SyntaxVisitor {
        var facts = Institute.Inventory.Facts()
        var scopes: [Scope] = []
        /// Whether each visited scope-bearing declaration pushed a scope.
        var pushed: [Swift.Bool] = []
        let converter: SourceLocationConverter

        init(tree: SourceFileSyntax) {
            converter = SourceLocationConverter(fileName: "", tree: tree)
            super.init(viewMode: .sourceAccurate)
        }

        var from: [Swift.String] {
            scopes.last { $0.kind != .generics }?.path ?? []
        }

        var moduleSelector: Swift.String {
            scopes.last { $0.kind != .generics }?.moduleSelector ?? ""
        }

        func line(_ node: some SyntaxProtocol) -> Swift.Int {
            node.startLocation(converter: converter).line
        }

        // MARK: Type declarations

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            declare(
                node, name: node.name, kind: "struct", modifiers: node.modifiers,
                generics: node.genericParameterClause, inheritance: node.inheritanceClause,
                members: node.memberBlock
            )
            return .visitChildren
        }
        override func visitPost(_ node: StructDeclSyntax) { pop() }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            declare(
                node, name: node.name, kind: "enum", modifiers: node.modifiers,
                generics: node.genericParameterClause, inheritance: node.inheritanceClause,
                members: node.memberBlock
            )
            return .visitChildren
        }
        override func visitPost(_ node: EnumDeclSyntax) { pop() }

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            declare(
                node, name: node.name, kind: "class", modifiers: node.modifiers,
                generics: node.genericParameterClause, inheritance: node.inheritanceClause,
                members: node.memberBlock
            )
            return .visitChildren
        }
        override func visitPost(_ node: ClassDeclSyntax) { pop() }

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            declare(
                node, name: node.name, kind: "actor", modifiers: node.modifiers,
                generics: node.genericParameterClause, inheritance: node.inheritanceClause,
                members: node.memberBlock
            )
            return .visitChildren
        }
        override func visitPost(_ node: ActorDeclSyntax) { pop() }

        override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
            let associated = Self.members(node.memberBlock).compactMap {
                $0.as(AssociatedTypeDeclSyntax.self).map { Self.strip($0.name.text) }
            }
            declare(
                node, name: node.name, kind: "protocol", modifiers: node.modifiers,
                generics: nil, inheritance: node.inheritanceClause,
                members: node.memberBlock, extraGenerics: associated
            )
            return .visitChildren
        }
        override func visitPost(_ node: ProtocolDeclSyntax) { pop() }

        override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
            if Self.inBody(Syntax(node)) {
                pushGenerics(node.genericParameterClause)
                return .visitChildren
            }
            let path = from + [Self.strip(node.name.text)]
            facts.types.append(
                .init(
                    path: path,
                    moduleSelector: moduleSelector,
                    kind: "typealias",
                    access: effectiveAccess(node.modifiers),
                    genericParameters: Self.names(node.genericParameterClause),
                    cases: -1,
                    storedProperties: 0,
                    inherits: [],
                    aliased: node.initializer.value.trimmedDescription,
                    inExtension: scopes.last?.kind == .extension,
                    condition: Self.condition(Syntax(node)),
                    line: line(node)
                )
            )
            pushGenerics(node.genericParameterClause)
            return .visitChildren
        }
        override func visitPost(_ node: TypeAliasDeclSyntax) { pop() }

        override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            let (module, chain) = Self.chain(node.extendedType) ?? ("", [node.extendedType.trimmedDescription])
            let written = Self.access(node.modifiers)
            let members = Self.members(node.memberBlock)
            let publicMembers = members.filter { member in
                let own = Self.access(Self.modifiers(member))
                return own == "public" || (own.isEmpty && written == "public")
            }.count
            facts.extensions.append(
                .init(
                    extended: chain,
                    moduleSelector: module,
                    conformances: Self.inherited(node.inheritanceClause),
                    whereClause: node.genericWhereClause?.requirements.trimmedDescription ?? "",
                    publicMembers: publicMembers,
                    nestedTypes: members.filter(Self.isTypeDeclaration).count,
                    condition: Self.condition(Syntax(node)),
                    line: line(node)
                )
            )
            scopes.append(
                .init(
                    kind: .extension, path: chain, generics: [], moduleSelector: module,
                    access: written == "private" ? "fileprivate" : written
                )
            )
            pushed.append(true)
            return .visitChildren
        }
        override func visitPost(_ node: ExtensionDeclSyntax) { pop() }

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            pushGenerics(node.genericParameterClause)
            return .visitChildren
        }
        override func visitPost(_ node: FunctionDeclSyntax) { pop() }

        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            pushGenerics(node.genericParameterClause)
            return .visitChildren
        }
        override func visitPost(_ node: InitializerDeclSyntax) { pop() }

        override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
            pushGenerics(node.genericParameterClause)
            return .visitChildren
        }
        override func visitPost(_ node: SubscriptDeclSyntax) { pop() }

        // MARK: Imports

        override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
            var components = node.path.map { Self.strip($0.name.text) }
            if node.importKindSpecifier != nil, components.count > 1 { components.removeLast() }
            let attributes = node.attributes.compactMap { element -> Swift.String? in
                element.as(AttributeSyntax.self)?.attributeName.trimmedDescription
            }
            facts.imports.append(
                .init(
                    module: components.joined(separator: "."),
                    access: Self.access(node.modifiers),
                    exported: attributes.contains("_exported"),
                    attributes: attributes.joined(separator: ","),
                    condition: Self.condition(Syntax(node))
                )
            )
            return .skipChildren
        }

        // MARK: References

        override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
            if let member = node.parent?.as(MemberTypeSyntax.self), member.baseType.id == node.id {
                return .visitChildren
            }
            reference(TypeSyntax(node))
            return .visitChildren
        }

        override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
            if let member = node.parent?.as(MemberTypeSyntax.self), member.baseType.id == node.id {
                return .visitChildren
            }
            reference(TypeSyntax(node))
            return .visitChildren
        }

        override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
            if let member = node.parent?.as(MemberAccessExprSyntax.self), member.declName.id == node.id {
                return .visitChildren
            }
            let name = Self.strip(node.baseName.text)
            guard Self.capitalised(name) else { return .visitChildren }
            var chain = [name]
            var current = Syntax(node)
            while let parent = current.parent {
                if let specialised = parent.as(GenericSpecializationExprSyntax.self),
                    specialised.expression.id == current.id
                {
                    current = parent
                    continue
                }
                if let member = parent.as(MemberAccessExprSyntax.self), member.base?.id == current.id {
                    let next = Self.strip(member.declName.baseName.text)
                    guard Self.capitalised(next) else { break }
                    chain.append(next)
                    current = parent
                    continue
                }
                break
            }
            record(
                module: node.moduleSelector.map { Self.strip($0.moduleName.text) } ?? "",
                chain: chain,
                position: Self.inBody(Syntax(node)) ? .body : .other
            )
            return .visitChildren
        }

        func reference(_ type: TypeSyntax) {
            guard let (module, chain) = Self.chain(type) else { return }
            record(module: module, chain: chain, position: Self.position(Syntax(type)))
        }

        func record(module: Swift.String, chain: [Swift.String], position: Institute.Inventory.Position) {
            guard let first = chain.first else { return }
            if first == "Self" && chain.count == 1 { return }
            if first == "_" || first == "Any" && chain.count == 1 { return }
            let generic = module.isEmpty && scopes.contains { $0.generics.contains(first) }
            facts.references.append(
                .init(
                    from: position == .extension ? [] : from,
                    module: module,
                    chain: chain,
                    position: position,
                    generic: generic
                )
            )
        }

        // MARK: Scope bookkeeping

        func declare(
            _ node: some DeclSyntaxProtocol,
            name: TokenSyntax,
            kind: Swift.String,
            modifiers: DeclModifierListSyntax,
            generics: GenericParameterClauseSyntax?,
            inheritance: InheritanceClauseSyntax?,
            members: MemberBlockSyntax,
            extraGenerics: [Swift.String] = []
        ) {
            if Self.inBody(Syntax(node)) {
                pushed.append(false)
                return
            }
            let path = from + [Self.strip(name.text)]
            let flattened = Self.members(members)
            let cases =
                kind == "enum"
                ? flattened.reduce(0) { $0 + ($1.as(EnumCaseDeclSyntax.self)?.elements.count ?? 0) }
                : -1
            let stored = flattened.reduce(0) { total, member in
                guard let variable = member.as(VariableDeclSyntax.self) else { return total }
                return total + Self.storedBindings(variable)
            }
            let enclosing = scopes.last
            let effective = effectiveAccess(modifiers)
            let parameters = Self.names(generics)
            facts.types.append(
                .init(
                    path: path,
                    moduleSelector: moduleSelector,
                    kind: kind,
                    access: effective,
                    genericParameters: parameters,
                    associatedTypes: extraGenerics,
                    cases: cases,
                    storedProperties: stored,
                    inherits: Self.inherited(inheritance),
                    aliased: "",
                    inExtension: enclosing?.kind == .extension,
                    condition: Self.condition(Syntax(node)),
                    line: line(node)
                )
            )
            scopes.append(
                .init(
                    kind: .type, path: path, generics: parameters + extraGenerics,
                    moduleSelector: moduleSelector, access: ""
                )
            )
            pushed.append(true)
        }

        func pushGenerics(_ clause: GenericParameterClauseSyntax?) {
            let names = Self.names(clause)
            guard !names.isEmpty else {
                pushed.append(false)
                return
            }
            scopes.append(.init(kind: .generics, path: [], generics: names, moduleSelector: "", access: ""))
            pushed.append(true)
        }

        func pop() {
            if pushed.popLast() == true { scopes.removeLast() }
        }

        /// The written access level; else the one written on the
        /// enclosing extension (`private` there is `fileprivate`); else
        /// `internal`.
        func effectiveAccess(_ modifiers: DeclModifierListSyntax) -> Swift.String {
            let written = Self.access(modifiers)
            if !written.isEmpty { return written }
            if let enclosing = scopes.last, enclosing.kind == .extension, !enclosing.access.isEmpty {
                return enclosing.access
            }
            return "internal"
        }
    }
}

extension Institute.Inventory.Walker.Visitor {
    static func strip(_ text: Swift.String) -> Swift.String {
        guard text.hasPrefix("`"), text.hasSuffix("`"), text.count >= 2 else { return text }
        return Swift.String(text.dropFirst().dropLast())
    }

    static func capitalised(_ name: Swift.String) -> Swift.Bool {
        guard let first = name.unicodeScalars.first else { return false }
        return first.properties.isUppercase
    }

    /// The chain a type names: `(module, ["A", "B"])` for `Module::A<X>.B`.
    static func chain(_ type: TypeSyntax) -> (Swift.String, [Swift.String])? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return (identifier.moduleSelector.map { strip($0.moduleName.text) } ?? "", [strip(identifier.name.text)])
        }
        if let member = type.as(MemberTypeSyntax.self) {
            guard let (module, base) = chain(member.baseType) else { return nil }
            return (module, base + [strip(member.name.text)])
        }
        if let attributed = type.as(AttributedTypeSyntax.self) {
            return chain(attributed.baseType)
        }
        return nil
    }

    /// The written access level, or empty. `open` is public; a setter's
    /// own level (`private(set)`) is not the declaration's.
    static func access(_ modifiers: DeclModifierListSyntax) -> Swift.String {
        for modifier in modifiers where modifier.detail == nil {
            switch modifier.name.text {
            case "public", "open": return "public"
            case "package": return "package"
            case "internal": return "internal"
            case "fileprivate": return "fileprivate"
            case "private": return "private"
            default: continue
            }
        }
        return ""
    }

    static func modifiers(_ declaration: DeclSyntax) -> DeclModifierListSyntax {
        declaration.asProtocol((any WithModifiersSyntax).self)?.modifiers ?? []
    }

    static func names(_ clause: GenericParameterClauseSyntax?) -> [Swift.String] {
        clause?.parameters.map { strip($0.name.text) } ?? []
    }

    static func inherited(_ clause: InheritanceClauseSyntax?) -> [Swift.String] {
        clause?.inheritedTypes.map { $0.type.trimmedDescription } ?? []
    }

    static func isTypeDeclaration(_ declaration: DeclSyntax) -> Swift.Bool {
        declaration.is(StructDeclSyntax.self) || declaration.is(EnumDeclSyntax.self)
            || declaration.is(ClassDeclSyntax.self) || declaration.is(ActorDeclSyntax.self)
            || declaration.is(ProtocolDeclSyntax.self) || declaration.is(TypeAliasDeclSyntax.self)
    }

    /// The member declarations of a body, with every `#if` clause opened.
    static func members(_ block: MemberBlockSyntax) -> [DeclSyntax] {
        var result: [DeclSyntax] = []
        func collect(_ list: MemberBlockItemListSyntax) {
            for item in list {
                if let conditional = item.decl.as(IfConfigDeclSyntax.self) {
                    for clause in conditional.clauses {
                        if case .decls(let nested) = clause.elements { collect(nested) }
                    }
                } else {
                    result.append(item.decl)
                }
            }
        }
        collect(block.members)
        return result
    }

    /// The stored instance properties one `var` or `let` declares: each
    /// binding without accessors, or with only observers.
    static func storedBindings(_ variable: VariableDeclSyntax) -> Swift.Int {
        if variable.modifiers.contains(where: { ["static", "class"].contains($0.name.text) }) { return 0 }
        return variable.bindings.filter { binding in
            guard let block = binding.accessorBlock else { return true }
            switch block.accessors {
            case .getter: return false
            case .accessors(let accessors):
                return accessors.allSatisfy { ["willSet", "didSet"].contains($0.accessorSpecifier.text) }
            }
        }.count
    }

    /// Whether `node` sits inside a function, accessor or closure body.
    static func inBody(_ node: Syntax) -> Swift.Bool {
        var current = node
        while let parent = current.parent {
            if parent.is(CodeBlockSyntax.self) || parent.is(ClosureExprSyntax.self) { return true }
            if let block = parent.as(AccessorBlockSyntax.self), case .getter = block.accessors { return true }
            if parent.is(MemberBlockSyntax.self) || parent.is(SourceFileSyntax.self) { return false }
            current = parent
        }
        return false
    }

    /// Where, outside a body, a type is named.
    static func position(_ node: Syntax) -> Institute.Inventory.Position {
        if inBody(node) { return .body }
        var current = node
        while let parent = current.parent {
            if parent.is(GenericArgumentSyntax.self) { return .genericArgument }
            if parent.is(InheritanceClauseSyntax.self) { return .inheritance }
            if parent.is(GenericWhereClauseSyntax.self) || parent.is(GenericParameterSyntax.self) {
                return .constraint
            }
            if let declaration = parent.as(ExtensionDeclSyntax.self), declaration.extendedType.id == current.id {
                return .extension
            }
            if parent.is(TypeInitializerClauseSyntax.self) {
                return parent.parent?.is(TypeAliasDeclSyntax.self) == true ? .alias : .other
            }
            if parent.is(EnumCaseParameterSyntax.self) { return .case }
            if parent.is(FunctionParameterSyntax.self) || parent.is(ClosureParameterSyntax.self) {
                return .parameter
            }
            if parent.is(ReturnClauseSyntax.self), parent.parent?.is(FunctionTypeSyntax.self) != true {
                return .return
            }
            if parent.is(TypeAnnotationSyntax.self), let binding = parent.parent?.as(PatternBindingSyntax.self) {
                guard let block = binding.accessorBlock else { return .stored }
                switch block.accessors {
                case .getter: return .return
                case .accessors(let accessors):
                    let observers = accessors.allSatisfy { ["willSet", "didSet"].contains($0.accessorSpecifier.text) }
                    return observers ? .stored : .return
                }
            }
            if parent.isProtocol((any DeclSyntaxProtocol).self) || parent.is(MemberBlockSyntax.self) {
                return .other
            }
            current = parent
        }
        return .other
    }

    /// The text of the enclosing `#if` clause chain, outermost first:
    /// `A`, `!(A) && B` for an `#elseif B`, `!(A) && !(B)` for an `#else`.
    static func condition(_ node: Syntax) -> Swift.String {
        var parts: [Swift.String] = []
        var current = node
        while let parent = current.parent {
            if let clause = parent.as(IfConfigClauseSyntax.self),
                let declaration = clause.parent?.parent?.as(IfConfigDeclSyntax.self)
            {
                var terms: [Swift.String] = []
                for other in declaration.clauses {
                    if other.id == clause.id {
                        if let condition = other.condition { terms.append(condition.trimmedDescription) }
                        break
                    }
                    if let condition = other.condition { terms.append("!(\(condition.trimmedDescription))") }
                }
                let text = terms.joined(separator: " && ")
                parts.append(text)
            }
            current = parent
        }
        let ordered = parts.reversed()
        if ordered.count <= 1 { return ordered.first ?? "" }
        return ordered.map { $0.contains("&&") || $0.contains("||") ? "(\($0))" : $0 }.joined(separator: " && ")
    }
}
