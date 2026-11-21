internal import Institute_Linter_Rule_Manifest
public import Institute_Model
public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `capability before noun` = Lint.Rule.`capability before noun`(in: nil)

    public static func `capability before noun`(in repository: Institute.Repository.Coordinate?) -> Lint.Rule {
        Lint.Rule(
            id: "capability before noun",
            default: .warning,
            suppression: .both,
            controls: architectureCapabilityBeforeNounControls(in: repository),
            observe: { source, severity in
                guard let target = manifestSourceTarget(ofPath: source.file.filePath),
                    !target.hasSuffix("Test Support"),
                    !target.split(separator: " ").contains(where: { $0 == "Macro" || $0 == "Macros" })
                else {
                    return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
                }
                let visitor = ArchitectureCapabilityBeforeNounVisitor(
                    source: source.file,
                    severity: severity,
                    converter: source.converter,
                    package: repository?.name
                )
                visitor.walk(source.tree)
                return Lint.Rule.Observation(findings: visitor.matches, coverage: .measured)
            }
        )
    }
}

private let architectureCapabilityCatalog: Swift::Set<Swift::String> = [
    "Formatter",
    "Parser",
    "Coder",
    "Encoder",
    "Decoder",
    "Serializer",
    "Renderer",
    "View",
    "Builder",
    "Store",
    "Client",
    "Cache",
    "Machine",
]

private let architectureCapabilitySupportNames: Swift::Set<Swift::String> = [
    "Error",
    "Options",
    "Option",
    "Context",
    "State",
    "CodingKeys",
]

private func architectureCapabilityBeforeNounControls(
    in repository: Institute.Repository.Coordinate?
) -> [Lint.Rule.Control] {
    let name = repository?.name ?? "swift-radix"
    let root = "/workspace/\(name)"
    let isFormatterOwner = architectureCapabilityNormalizedKey(package: name) == "formatter"
    return [
        .init(
            id: "capability before noun inverted extension",
            source: "extension Formatter {\n    public struct Radix {}\n}",
            path: "\(root)/Sources/Radix/Formatter.Radix.swift",
            expectation: isFormatterOwner ? .clean : .findings(1)
        ),
        .init(
            id: "capability before noun noun then capability",
            source: "extension Radix {\n    public struct Formatter {}\n}",
            path: "\(root)/Sources/Radix/Radix.Formatter.swift",
            expectation: .clean
        ),
        .init(
            id: "capability before noun support type under capability",
            source: "extension Formatter {\n    public enum Error: Swift.Error {}\n}",
            path: "\(root)/Sources/Radix/Formatter.Error.swift",
            expectation: .clean
        ),
        .init(
            id: "capability before noun repeated capability nesting",
            source: "extension Machine.Parser {\n    public struct Parser {}\n}",
            path: "\(root)/Sources/Radix/Machine.Parser.Parser.swift",
            expectation: .findings(1)
        ),
        .init(
            id: "capability before noun tests exempt",
            source: "extension Formatter {\n    public struct Radix {}\n}",
            path: "\(root)/Tests/Radix Tests/Formatter.Radix.swift",
            expectation: .clean,
            applicability: .inapplicable
        ),
    ]
}

private func architectureCapabilityNormalizedKey(package: Swift::String) -> Swift::String {
    let stripped = package.hasPrefix("swift-") ? package.dropFirst("swift-".count) : Swift::Substring(package)
    return stripped.filter { $0 != "-" }.lowercased()
}

private func architectureCapabilityNormalizedKey(type: Swift::String) -> Swift::String {
    type.filter { $0 != "_" && $0 != "`" }.lowercased()
}

internal final class ArchitectureCapabilityBeforeNounVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    let package: Swift::String?
    var ownedTopLevelTypes: Swift::Set<Swift::String> = []
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        package: Swift::String?
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.package = package
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind {
        collectTopLevelTypes(node.statements)
        inspect(node.statements, prefix: [])
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
                ownedTopLevelTypes.insert(name)
            }
        }
    }

    private func inspect(_ statements: CodeBlockItemListSyntax, prefix: [Swift::String]) {
        for statement in statements {
            guard let decl = statement.item.as(DeclSyntax.self) else { continue }
            if let conditional = decl.as(IfConfigDeclSyntax.self) {
                for clause in conditional.clauses {
                    if case .statements(let nested) = clause.elements {
                        inspect(nested, prefix: prefix)
                    }
                }
                continue
            }
            if let ext = decl.as(ExtensionDeclSyntax.self) {
                let segments = typeSegments(of: ext.extendedType)
                inspectMembers(ext.memberBlock.members, prefix: prefix + segments)
                continue
            }
            if let member = nominalDecl(of: decl) {
                let path = prefix + [member.name]
                if member.isPublicOrPackage {
                    check(path: path, position: member.token.positionAfterSkippingLeadingTrivia)
                }
                inspectMembers(member.members, prefix: path)
            }
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
            if let member = nominalDecl(of: decl) {
                let path = prefix + [member.name]
                if member.isPublicOrPackage {
                    check(path: path, position: member.token.positionAfterSkippingLeadingTrivia)
                }
                inspectMembers(member.members, prefix: path)
            }
        }
    }

    private func check(path: [Swift::String], position: AbsolutePosition) {
        guard path.count >= 2, let root = path.first, let leaf = path.last else { return }
        let full = path.joined(separator: ".")

        if architectureCapabilityCatalog.contains(leaf),
            path.dropLast().contains(where: { architectureCapabilityCatalog.contains($0) }),
            path.dropLast().last == leaf
        {
            emit(
                position: position,
                message: "[capability before noun] [ARCH-PHRASE-003]: `\(full)` nests capability `\(leaf)` "
                    + "inside itself. Capabilities belong once at the end of the noun chain "
                    + "(`Noun.Capability`), with only support types (`.Error`, `.Options`, `.Context`) beneath them."
            )
            return
        }

        guard architectureCapabilityCatalog.contains(root),
            !architectureCapabilitySupportNames.contains(leaf),
            !ownedTopLevelTypes.contains(root)
        else { return }
        if let package,
            architectureCapabilityNormalizedKey(package: package)
                == architectureCapabilityNormalizedKey(type: root)
        {
            return
        }
        emit(
            position: position,
            message: "[capability before noun] [ARCH-PHRASE-003]: `\(full)` nests `\(leaf)` under "
                + "capability root `\(root)`. Invert ownership by extending the noun with the capability at the end "
                + "(`\(leaf).\(root)`), keeping only support types beneath the capability."
        )
    }

    private func emit(position: AbsolutePosition, message: Swift::String) {
        let location = converter.location(for: position)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "capability before noun",
                message: message
            )
        )
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
    ) -> (name: Swift::String, token: TokenSyntax, isPublicOrPackage: Swift::Bool, members: MemberBlockItemListSyntax)? {
        if let node = decl.as(StructDeclSyntax.self) {
            return (unescaped(node.name.text), node.name, isExposed(node.modifiers), node.memberBlock.members)
        }
        if let node = decl.as(EnumDeclSyntax.self) {
            return (unescaped(node.name.text), node.name, isExposed(node.modifiers), node.memberBlock.members)
        }
        if let node = decl.as(ClassDeclSyntax.self) {
            return (unescaped(node.name.text), node.name, isExposed(node.modifiers), node.memberBlock.members)
        }
        if let node = decl.as(ActorDeclSyntax.self) {
            return (unescaped(node.name.text), node.name, isExposed(node.modifiers), node.memberBlock.members)
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
