internal import File_System
package import Lint
internal import Linter_Rule_Scope
internal import SwiftParser
package import SwiftSyntax
internal import Synchronization

/// What one source file declares that the package rules read: whether it declares anything at all, the types,
/// typealiases and macros it declares with their dotted paths, and the traits its content is gated by.
package struct ManifestSourceFacts: Sendable {
    /// Whether the file holds only imports, or imports and namespace enums with no cases and no members.
    package let empty: Swift::Bool
    package let declarations: [Declaration]
    package let gate: Gate
}

extension ManifestSourceFacts {
    package struct Declaration: Sendable {
        package enum Kind: Sendable, Equatable {
            case type
            case alias
            case macro
        }

        /// The dotted path, without backticks or generic arguments: `IETF.RFC.3986.URI`.
        package let path: [Swift::String]
        /// The path together with the requirements of the extensions it is declared in and the `#if` conditions
        /// around it: two declarations are of one path only when their keys are equal.
        package let key: Swift::String
        package let kind: Kind
        package let isPublic: Swift::Bool
        package let position: AbsolutePosition
    }

    /// How a file's content is wrapped in conditional compilation.
    package enum Gate: Sendable, Equatable {
        /// The file holds nothing but imports.
        case none
        /// Every declaration of the file is inside an `#if` whose first condition names these identifiers.
        case gated(Swift::Set<Swift::String>)
        /// Some of the file's content is outside any `#if`.
        case open
    }

    package init(tree: SourceFileSyntax) {
        var walker = ManifestSourceWalker()
        walker.statements(tree.statements, scope: .init())
        self.empty = walker.empty
        self.declarations = walker.declarations
        self.gate = manifestSourceGate(tree.statements)
    }
}

private func manifestSourceGate(_ statements: CodeBlockItemListSyntax) -> ManifestSourceFacts.Gate {
    var identifiers: Swift::Set<Swift::String> = []
    var content = false
    for statement in statements {
        if statement.item.as(ImportDeclSyntax.self) != nil { continue }
        content = true
        guard let conditional = statement.item.as(IfConfigDeclSyntax.self),
            let condition = conditional.clauses.first?.condition
        else { return .open }
        for token in condition.tokens(viewMode: .sourceAccurate) {
            if case .identifier(let name) = token.tokenKind { identifiers.insert(name) }
        }
    }
    return content ? .gated(identifiers) : .none
}

private struct ManifestSourceScope {
    var path: [Swift::String] = []
    var requirements: [Swift::String] = []
    var conditions: [Swift::String] = []
    var publicByDefault = false
}

private struct ManifestSourceWalker {
    var empty = true
    var declarations: [ManifestSourceFacts.Declaration] = []

    mutating func statements(_ list: CodeBlockItemListSyntax, scope: ManifestSourceScope) {
        for statement in list {
            guard let declaration = statement.item.as(DeclSyntax.self) else {
                empty = false
                continue
            }
            self.declaration(declaration, scope: scope)
        }
    }

    mutating func members(_ list: MemberBlockItemListSyntax, scope: ManifestSourceScope) {
        for member in list {
            declaration(member.decl, scope: scope)
        }
    }

    mutating func declaration(_ declaration: DeclSyntax, scope: ManifestSourceScope) {
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
        scope: ManifestSourceScope
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
        scope: ManifestSourceScope
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
package func manifestTypePath(_ written: Swift::String) -> [Swift::String] {
    var depth = 0
    var stripped = ""
    for character in written {
        if character == "<" { depth += 1 } else if character == ">" { depth -= 1 } else if depth == 0 { stripped.append(character) }
    }
    return stripped.split(separator: ".").map { $0.filter { $0 != "`" && !$0.isWhitespace } }
}

/// The facts of every source file of a package on disk, read once per package root: its manifest's graph, and for
/// each target that is not a test target the files of its folder, by their path relative to the root.
package struct ManifestPackageSources: Sendable {
    package let graph: ManifestGraph
    /// The files each target that is not a test target owns, sorted, relative to the root.
    package let files: [Swift::String: [Swift::String]]
    package let facts: [Swift::String: ManifestSourceFacts]
    /// The target that owns each file: of two targets whose folders hold it, the one with the deeper folder.
    private let owners: [Swift::String: Swift::String]
    /// Every file of a target that is not a test target, sorted, once.
    package let allFiles: [Swift::String]

    private init(graph: ManifestGraph, files: [Swift::String: [Swift::String]], facts: [Swift::String: ManifestSourceFacts]) {
        self.graph = graph
        self.facts = facts
        var owners: [Swift::String: Swift::String] = [:]
        for target in graph.targets.sorted(by: { $0.directory.count < $1.directory.count }) {
            for file in files[target.name] ?? [] { owners[file] = target.name }
        }
        self.owners = owners
        self.allFiles = owners.keys.sorted()
        var owned: [Swift::String: [Swift::String]] = [:]
        for file in allFiles {
            if let owner = owners[file] { owned[owner, default: []].append(file) }
        }
        self.files = owned
    }
}

extension ManifestPackageSources {
    private static let cache = Mutex<[Swift::String: ManifestPackageSources]>([:])

    /// The sources of the package `source` is in, when the package is on disk.
    package static func of(_ source: borrowing Lint.Source.Parsed) -> Self? {
        if let root = Lint.Scope.File.root(of: source) { return of(root: root) }
        // A run over `.` names its files `./Sources/…`: the package is the working directory.
        let file = Swift::String(source.file.filePath.map { $0 == "\\" ? "/" : $0 })
        let relative = source.relativePath
        guard file.hasPrefix("./"), !relative.isEmpty, file.hasSuffix("/" + relative) else { return nil }
        let root = Swift::String(file.dropLast(relative.count + 1))
        guard Lint.Scope.File.isFile(root + "/Package.swift") else { return nil }
        return of(root: root)
    }

    package static func of(root: Swift::String) -> Self? {
        if let hit = cache.withLock({ $0[root] }) { return hit }
        guard let text = Lint.Scope.File.text(at: root + "/Package.swift") else { return nil }
        let graph = ManifestGraph(tree: Parser.parse(source: text))
        var files: [Swift::String: [Swift::String]] = [:]
        var facts: [Swift::String: ManifestSourceFacts] = [:]
        for target in graph.targets where target.kind != .test && target.kind != .other {
            guard let directory = try? File.Directory(validating: root + "/" + target.directory) else { continue }
            let paths = Lint.Scope.File.swiftFiles(under: directory).map { Swift::String($0.dropFirst(root.count + 1)) }
            files[target.name] = paths
            for path in paths where facts[path] == nil {
                guard let text = Lint.Scope.File.text(at: root + "/" + path) else { continue }
                facts[path] = ManifestSourceFacts(tree: Parser.parse(source: text))
            }
        }
        let sources = Self(graph: graph, files: files, facts: facts)
        cache.withLock { $0[root] = sources }
        return sources
    }

    /// The target whose folder holds `path`, relative to the root.
    package func target(containing path: Swift::String) -> ManifestGraph.Target? {
        owners[path].flatMap(graph.target(named:))
    }
}

extension Lint.Source.Parsed {
    /// The file's path relative to its package root, written with `/`.
    package var relativePath: Swift::String {
        path.underlying.split(separator: "/", omittingEmptySubsequences: true).filter { $0 != "." }.joined(separator: "/")
    }
}
