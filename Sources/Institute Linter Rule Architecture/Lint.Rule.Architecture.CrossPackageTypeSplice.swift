internal import Institute_Linter_Rule_Manifest
public import Institute_Model
public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `cross package type splice` = Lint.Rule.`cross package type splice`(in: nil)

    public static func `cross package type splice`(in repository: Institute.Repository.Coordinate?) -> Lint.Rule {
        Lint.Rule(
            id: "cross package type splice",
            default: .warning,
            suppression: .both,
            controls: architectureCrossPackageTypeSpliceControls(in: repository),
            observe: { source, severity in
                guard let repository,
                    let target = manifestSourceTarget(ofPath: source.file.filePath),
                    !target.hasSuffix("Test Support"),
                    !target.split(separator: " ").contains(where: { $0 == "Macro" || $0 == "Macros" })
                else {
                    return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
                }
                let visitor = ArchitectureCrossPackageTypeSpliceVisitor(
                    source: source.file,
                    severity: severity,
                    converter: source.converter,
                    repository: repository
                )
                visitor.walk(source.tree)
                return Lint.Rule.Observation(findings: visitor.matches, coverage: .measured)
            }
        )
    }
}

private let architectureSpliceCapabilities: Swift::Set<Swift::String> = [
    "Formatter",
    "Parser",
    "Parse",
    "Coder",
    "Encoder",
    "Decoder",
    "Serializer",
    "Serialize",
    "Renderer",
    "Render",
    "View",
    "Builder",
    "Store",
    "Client",
    "Cache",
    "Machine",
]

private func architectureCrossPackageTypeSpliceControls(
    in repository: Institute.Repository.Coordinate?
) -> [Lint.Rule.Control] {
    guard let repository else {
        return [
            .init(
                id: "cross package type splice without repository",
                source: "extension Picture {\n    public enum Watercolor {}\n}",
                path: "/workspace/swift-picture-watercolor/Sources/Picture Watercolor/Picture.Watercolor.swift",
                expectation: .clean,
                applicability: .inapplicable
            )
        ]
    }
    let name = repository.name
    let root = "/workspace/\(name)"
    let isPictureOwner = architectureSpliceOwns(root: "Picture", repository: repository)
    let isForeignAllowed = architectureSpliceOwns(root: "Translation", repository: repository)
    return [
        .init(
            id: "cross package type splice foreign domain",
            source: "extension Translation {\n    public struct Rule {}\n}",
            path: "\(root)/Sources/Core/Translation.Rule.swift",
            expectation: isForeignAllowed ? .clean : .findings(1)
        ),
        .init(
            id: "cross package type splice capability on noun allowed",
            source: "extension Radix {\n    public struct Formatter {}\n}",
            path: "\(root)/Sources/Core/Radix.Formatter.swift",
            expectation: .clean
        ),
        .init(
            id: "cross package type splice nested support under capability allowed",
            source: "extension Binary.Parser {\n    public enum Error: Swift.Error {}\n}",
            path: "\(root)/Sources/Core/Binary.Parser.Error.swift",
            expectation: .clean
        ),
        .init(
            id: "cross package type splice swift extension allowed",
            source: "extension Swift.Character {\n    public enum Case {}\n}",
            path: "\(root)/Sources/Core/Swift.Character.Case.swift",
            expectation: .clean
        ),
        .init(
            id: "cross package type splice own type in file allowed",
            source: "public enum LocalRoot {}\nextension LocalRoot {\n    public struct Child {}\n}",
            path: "\(root)/Sources/Core/LocalRoot.swift",
            expectation: .clean
        ),
        .init(
            id: "cross package type splice composition peer splice",
            source: "extension Picture {\n    public enum Watercolor {}\n}",
            path: "\(root)/Sources/Core/Picture.Watercolor.swift",
            expectation: isPictureOwner ? .clean : .findings(1)
        ),
        .init(
            id: "cross package type splice tests exempt",
            source: "extension Translation {\n    public struct Rule {}\n}",
            path: "\(root)/Tests/Core Tests/Translation.Rule.swift",
            expectation: .clean,
            applicability: .inapplicable
        ),
    ]
}

private func architectureSpliceNormalizedPackage(_ name: Swift::String) -> Swift::String {
    let stripped = name.hasPrefix("swift-") ? name.dropFirst("swift-".count) : Swift::Substring(name)
    return stripped.filter { $0 != "-" }.lowercased()
}

private func architectureSpliceNormalizedType(_ name: Swift::String) -> Swift::String {
    name.filter { $0 != "_" && $0 != "`" }.lowercased()
}

private func architectureSpliceOwns(
    root: Swift::String,
    repository: Institute.Repository.Coordinate
) -> Swift::Bool {
    let rootKey = architectureSpliceNormalizedType(root)
    let packageName = repository.name
    let stem = packageName.hasPrefix("swift-") ? Swift::String(packageName.dropFirst("swift-".count)) : packageName
    let packageKey = stem.filter { $0 != "-" }.lowercased()
    let words = stem.split(separator: "-").map { $0.lowercased() }

    if packageKey == rootKey { return true }
    if packageKey == rootKey + "s" || packageKey == rootKey + "es" || packageKey == rootKey + "er" { return true }
    if packageKey == rootKey + "standard" || packageKey == rootKey + "primitives" { return true }

    if repository.organization.layer <= .molecules {
        if let first = words.first, first == rootKey { return true }
        if words.count >= 2, (words[0] + words[1]) == rootKey { return true }
    }

    if let first = words.first, first == rootKey {
        let sameRootCompositions: Swift::Set<Swift::String> = [
            "file", "kernel", "lint", "linter", "package", "manifest", "github", "store", "witness", "test", "memory",
            "byte", "async", "buffer", "http", "html", "pdf", "sql",
        ]
        if sameRootCompositions.contains(first) { return true }
    }
    if rootKey == "package", packageKey == "spmstandard" { return true }

    if repository.organization.layer == .standards {
        switch repository.organization {
        case .`swift-whatwg`:
            if rootKey == "whatwg" { return true }

        case .`swift-w3c`:
            if ["w3c", "css", "png", "svg", "dom"].contains(rootKey) { return true }

        case .`swift-bipm`:
            if rootKey == "si" || rootKey == "bipm" { return true }

        case .`swift-linux-foundation`:
            if rootKey == "linux" { return true }

        case .`swift-microsoft`:
            if rootKey == "windows" || rootKey == "win32" { return true }

        case .`swift-arm-ltd`:
            if rootKey == "arm" || rootKey == "cpu" { return true }

        case .`swift-intel`:
            if rootKey == "x86" || rootKey == "intel" || rootKey == "cpu" { return true }

        case .`swift-riscv`:
            if rootKey == "riscv" || rootKey == "cpu" { return true }

        case .`swift-standards`:
            if let first = words.first, first == rootKey { return true }
            if rootKey == "si", packageKey == "internationalsystemofunits" { return true }
            if rootKey == "cpu", ["x86", "arm", "riscv"].contains(words.first ?? "") { return true }

        default:
            break
        }
    }

    return false
}

internal final class ArchitectureCrossPackageTypeSpliceVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    let repository: Institute.Repository.Coordinate
    var declaredTopLevelTypes: Swift::Set<Swift::String> = []
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        repository: Institute.Repository.Coordinate
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.repository = repository
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind {
        collectTopLevelTypes(node.statements)
        inspect(node.statements)
        return .skipChildren
    }

    private func collectTopLevelTypes(_ statements: CodeBlockItemListSyntax) {
        for statement in statements {
            guard let decl = statement.item.as(DeclSyntax.self) else { continue }
            if let conditional = decl.as(IfConfigDeclSyntax.self) {
                for clause in conditional.clauses {
                    if case .statements(let nested) = clause.elements {
                        collectTopLevelTypes(nested)
                    }
                }
                continue
            }
            if let name = nominalName(of: decl) {
                declaredTopLevelTypes.insert(name)
            }
        }
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
            guard let ext = decl.as(ExtensionDeclSyntax.self) else { continue }
            let baseSegments = typeSegments(of: ext.extendedType)
            guard let root = baseSegments.first else { continue }
            guard root != "Swift",
                !declaredTopLevelTypes.contains(root),
                !architectureSpliceOwns(root: root, repository: repository)
            else { continue }
            inspectMembers(ext.memberBlock.members, prefix: baseSegments)
        }
    }

    private func inspectMembers(_ members: MemberBlockItemListSyntax, prefix: [Swift::String]) {
        for item in members {
            let decl = item.decl
            if let conditional = decl.as(IfConfigDeclSyntax.self) {
                for clause in conditional.clauses {
                    if case .decls(let nested) = clause.elements {
                        inspectMembers(nested, prefix: prefix)
                    }
                }
                continue
            }
            guard let member = nominalDecl(of: decl) else { continue }
            let path = prefix + [member.name]
            if member.isPublicOrPackage {
                let tailSegments = path.dropFirst()
                let isCapabilityOnNoun = tailSegments.contains { architectureSpliceCapabilities.contains($0) }
                if !isCapabilityOnNoun {
                    let full = path.joined(separator: ".")
                    let location = converter.location(for: member.token.positionAfterSkippingLeadingTrivia)
                    matches.append(
                        Diagnostic.Record(
                            location: Source.Location(
                                fileID: source.fileID,
                                filePath: source.filePath,
                                line: location.line,
                                column: location.column
                            ),
                            severity: severity,
                            identifier: "cross package type splice",
                            message: "[cross package type splice] [ARCH-PHRASE-002]: `\(repository.name)` declares "
                                + "`\(full)` inside foreign root `\(prefix[0])`. Cross-package nesting is reserved "
                                + "for inverted-ownership capabilities (`Noun.Formatter`, `Noun.Parser`, `Noun.View`) "
                                + "or same-domain layer splits (`Buffer.Linear`); declare a standalone root or move "
                                + "the type to `\(prefix[0])`'s package."
                        )
                    )
                }
            }
        }
    }

    private func typeSegments(of type: TypeSyntax) -> [Swift::String] {
        if let member = type.as(MemberTypeSyntax.self) {
            return typeSegments(of: member.baseType) + [unescaped(member.name.text)]
        }
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return [unescaped(identifier.name.text)]
        }
        return []
    }

    private func unescaped(_ raw: Swift::String) -> Swift::String {
        raw.filter { $0 != "`" }
    }

    private func nominalName(of decl: DeclSyntax) -> Swift::String? {
        if let node = decl.as(StructDeclSyntax.self) { return unescaped(node.name.text) }
        if let node = decl.as(EnumDeclSyntax.self) { return unescaped(node.name.text) }
        if let node = decl.as(ClassDeclSyntax.self) { return unescaped(node.name.text) }
        if let node = decl.as(ActorDeclSyntax.self) { return unescaped(node.name.text) }
        return nil
    }

    private func nominalDecl(
        of decl: DeclSyntax
    ) -> (name: Swift::String, token: TokenSyntax, isPublicOrPackage: Swift::Bool)? {
        if let node = decl.as(StructDeclSyntax.self) {
            return (unescaped(node.name.text), node.name, isExposed(node.modifiers))
        }
        if let node = decl.as(EnumDeclSyntax.self) {
            return (unescaped(node.name.text), node.name, isExposed(node.modifiers))
        }
        if let node = decl.as(ClassDeclSyntax.self) {
            return (unescaped(node.name.text), node.name, isExposed(node.modifiers))
        }
        if let node = decl.as(ActorDeclSyntax.self) {
            return (unescaped(node.name.text), node.name, isExposed(node.modifiers))
        }
        return nil
    }

    private func isExposed(_ modifiers: DeclModifierListSyntax) -> Swift::Bool {
        modifiers.contains {
            $0.name.tokenKind == .keyword(.public)
                || $0.name.tokenKind == .keyword(.open)
                || $0.name.tokenKind == .keyword(.package)
        }
    }
}
