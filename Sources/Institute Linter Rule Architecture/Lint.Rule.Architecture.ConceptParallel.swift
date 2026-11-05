public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    /// A second implementation of a concept that already has an owner.
    public static let `concept parallel` = Lint.Rule(
        id: "concept parallel",
        default: .warning,
        controls: [
            .init(
                id: "concept parallel framework call",
                source: "let status = SecItemCopyMatching(query, &item)",
                path: "Sources/Ledger Security/Read.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "concept parallel top-level type",
                source: "public struct Path: Sendable {}",
                path: "Sources/Paths/Path.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "concept parallel framework call in its owner",
                source: "let status = SecItemCopyMatching(query, &item)",
                path: "Sources/Keychain Security/Keychain.Item.swift",
                expectation: .clean
            ),
            .init(
                id: "concept parallel type in its owner",
                source: "public struct Path: Sendable {}",
                path: "Sources/Path/Path.swift",
                expectation: .clean
            ),
            .init(
                id: "concept parallel nested type",
                source: "extension Geometry {\n    public struct Path {}\n}\nextension License {\n    public struct Keychain {}\n}",
                path: "Sources/Geometry/Geometry.Path.swift",
                expectation: .clean
            ),
            .init(
                id: "concept parallel test",
                source: "let status = SecItemCopyMatching(query, &item)",
                path: "Tests/Ledger Tests/Read.swift",
                expectation: .clean
            ),
            .init(
                id: "concept parallel in a comment or string",
                source: "// SecItemAdd is not used here\nlet name = \"SecItemAdd\"",
                path: "Sources/Ledger/Notes.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            guard let target = Lint.Concept.target(of: source.file.filePath) else { return [] }
            let visitor = ConceptParallelVisitor(target: target)
            visitor.walk(source.tree)
            for statement in source.tree.statements {
                guard let name = conceptParallelTypeName(statement.item), let owner = Lint.Concept.types[name], owner != target
                else { continue }
                visitor.sites.append((statement.positionAfterSkippingLeadingTrivia, name, owner))
            }
            return visitor.sites.map { site in
                let location = source.converter.location(for: site.position)
                return Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "concept parallel",
                    message: "[concept parallel]: `\(site.name)` belongs to the target `\(site.owner)`. Fix: use the owner "
                        + "instead of a second implementation."
                )
            }
        }
    )
}

private func conceptParallelTypeName(_ item: CodeBlockItemSyntax.Item) -> Swift::String? {
    guard let declaration = item.as(DeclSyntax.self) else { return nil }
    if let type = declaration.as(StructDeclSyntax.self) { return type.name.text }
    if let type = declaration.as(EnumDeclSyntax.self) { return type.name.text }
    if let type = declaration.as(ClassDeclSyntax.self) { return type.name.text }
    if let type = declaration.as(ActorDeclSyntax.self) { return type.name.text }
    return nil
}

private final class ConceptParallelVisitor: SyntaxVisitor {
    let target: Swift::String
    var sites: [(position: AbsolutePosition, name: Swift::String, owner: Swift::String)] = []

    init(target: Swift::String) {
        self.target = target
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.baseName.text
        if let owner = Lint.Concept.functions[name], owner != target { sites.append((node.positionAfterSkippingLeadingTrivia, name, owner)) }
        return .visitChildren
    }
}
