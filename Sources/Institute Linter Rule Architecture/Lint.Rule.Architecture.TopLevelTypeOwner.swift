internal import Institute_Linter_Rule_Manifest
public import Lint
public import Institute_Model
internal import SwiftSyntax

extension Lint.Rule {
    public static let `top level type owner` = Lint.Rule.`top level type owner`(in: nil)

    public static func `top level type owner`(in repository: Institute.Repository.Coordinate?) -> Lint.Rule {
        Lint.Rule(
            id: "top level type owner",
            default: .warning,
            controls: architectureTopLevelTypeOwnerControls(in: repository),
            observe: { source, severity in
                guard let repository, repository.organization.layer <= .molecules,
                    let target = manifestSourceTarget(ofPath: source.file.filePath),
                    !target.hasSuffix("Test Support"),
                    !target.split(separator: " ").contains(where: { $0 == "Macro" || $0 == "Macros" })
                else {
                    return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
                }
                let visitor = ArchitectureTopLevelTypeOwnerVisitor(
                    source: source.file,
                    severity: severity,
                    converter: source.converter,
                    package: repository.name
                )
                visitor.walk(source.tree)
                return Lint.Rule.Observation(findings: visitor.matches, coverage: .measured)
            }
        )
    }
}

private func architectureTopLevelTypeOwnerControls(
    in repository: Institute.Repository.Coordinate?
) -> [Lint.Rule.Control] {
    let name = repository?.name ?? "swift-package"
    let root = "/workspace/\(name)"
    let words = (name.hasPrefix("swift-") ? name.dropFirst("swift-".count) : Swift::Substring(name))
        .split(separator: "-")
    let owner = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    let target = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    guard let repository, repository.organization.layer <= .molecules else {
        return [
            .init(
                id: "top level type owner outside atoms and molecules",
                source: "public enum \(owner) {}\npublic enum Zebra {}",
                path: "\(root)/Sources/\(target)/\(owner).swift",
                expectation: .clean,
                applicability: .inapplicable
            )
        ]
    }
    return [
        .init(
            id: "top level type owner second type",
            source: "public struct \(owner) {}\npublic struct Zebra {}",
            path: "\(root)/Sources/\(target)/\(owner).swift",
            expectation: .findings(1)
        ),
        .init(
            id: "top level type owner own type",
            source: "public enum \(owner) {}",
            path: "\(root)/Sources/\(target)/\(owner).swift",
            expectation: .clean
        ),
        .init(
            id: "top level type owner unrelated gerund protocol",
            source: "public protocol Zebraable {}",
            path: "\(root)/Sources/\(target)/Zebraable.swift",
            expectation: .findings(1)
        ),
        .init(
            id: "top level type owner conditional declaration",
            source: "#if Algebra\npublic struct Zebra {}\n#endif",
            path: "\(root)/Sources/\(target)/Zebra.swift",
            expectation: .findings(1)
        ),
        .init(
            id: "top level type owner internal type",
            source: "struct Zebra {}",
            path: "\(root)/Sources/\(target)/Zebra.swift",
            expectation: .clean
        ),
        .init(
            id: "top level type owner test support target",
            source: "public struct Zebra {}",
            path: "\(root)/Sources/\(target) Test Support/Zebra.swift",
            expectation: .clean,
            applicability: .inapplicable
        ),
        .init(
            id: "top level type owner macro target",
            source: "public struct Zebra {}",
            path: "\(root)/Sources/\(target) Macro Core/Zebra.swift",
            expectation: .clean,
            applicability: .inapplicable
        ),
        .init(
            id: "top level type owner macro near miss",
            source: "public struct Zebra {}",
            path: "\(root)/Sources/\(target) Macroscopic/Zebra.swift",
            expectation: .findings(1)
        ),
        .init(
            id: "top level type owner tests",
            source: "public struct Zebra {}",
            path: "\(root)/Tests/\(target) Tests/Zebra.swift",
            expectation: .clean,
            applicability: .inapplicable
        ),
        .init(
            id: "top level type owner bare filename",
            source: "public struct Zebra {}",
            path: "Zebra.swift",
            expectation: .clean,
            applicability: .inapplicable
        ),
    ]
}

private func architectureTopLevelTypeOwnerKey(package: Swift::String) -> Swift::String {
    let name = package.hasPrefix("swift-") ? package.dropFirst("swift-".count) : Swift::Substring(package)
    return name.filter { $0 != "-" }.lowercased()
}

private func architectureTopLevelTypeOwnerKey(type: Swift::String) -> Swift::String {
    type.filter { $0 != "_" }.lowercased()
}

private func architectureTopLevelTypeOwnerAllows(
    _ name: Swift::String,
    isProtocol: Swift::Bool,
    package: Swift::String
) -> Swift::Bool {
    let owner = architectureTopLevelTypeOwnerKey(package: package)
    let key = architectureTopLevelTypeOwnerKey(type: name)
    if key == owner { return true }
    guard isProtocol else { return false }
    for suffix in ["ing", "able"] where key.hasSuffix(suffix) {
        let stem = key.dropLast(suffix.count)
        if stem.count >= 3, owner.hasPrefix(stem) { return true }
    }
    return false
}

internal final class ArchitectureTopLevelTypeOwnerVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    let package: Swift::String
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        package: Swift::String
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.package = package
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind {
        inspect(node.statements)
        return .skipChildren
    }

    private func inspect(_ statements: CodeBlockItemListSyntax) {
        for statement in statements {
            guard let decl = statement.item.as(DeclSyntax.self) else { continue }
            if let conditional = decl.as(IfConfigDeclSyntax.self) {
                for clause in conditional.clauses {
                    if case .statements(let nested) = clause.elements {
                        inspect(nested)
                    }
                }
                continue
            }
            let declared: (name: TokenSyntax, modifiers: DeclModifierListSyntax, isProtocol: Swift::Bool)? =
                if let node = decl.as(StructDeclSyntax.self) {
                    (node.name, node.modifiers, false)
                } else if let node = decl.as(EnumDeclSyntax.self) {
                    (node.name, node.modifiers, false)
                } else if let node = decl.as(ClassDeclSyntax.self) {
                    (node.name, node.modifiers, false)
                } else if let node = decl.as(ActorDeclSyntax.self) {
                    (node.name, node.modifiers, false)
                } else if let node = decl.as(ProtocolDeclSyntax.self) {
                    (node.name, node.modifiers, true)
                } else {
                    nil
                }
            guard let declared,
                declared.modifiers.contains(where: {
                    $0.name.tokenKind == .keyword(.public) || $0.name.tokenKind == .keyword(.open)
                })
            else { continue }
            let name = declared.name.text.filter { $0 != "`" }
            guard !name.hasPrefix("_"),
                !architectureTopLevelTypeOwnerAllows(name, isProtocol: declared.isProtocol, package: package)
            else { continue }
            let location = converter.location(for: declared.name.positionAfterSkippingLeadingTrivia)
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "top level type owner",
                    message: "[top level type owner] [ARCH-ONE-TYPE]: `\(package)` declares the top-level "
                        + "type `\(name)`, which it is not named for. A repository owns one top-level "
                        + "type, the one its name spells, so a top-level `\(name)` belongs to its own "
                        + "repository and is declared nowhere else; nest it under the package's type, "
                        + "or move it out. `_`-prefixed declarations, typealiases, nested `Protocol`s "
                        + "and the type's gerund or `-able` protocol are allowed beside it."
                )
            )
        }
    }
}
