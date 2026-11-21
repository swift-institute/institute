internal import Institute_Linter_Rule_Manifest
public import Institute_Model
public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `domain nesting depth` = Lint.Rule.`domain nesting depth`(in: nil)

    public static let `product domain nesting depth` = architectureDomainNestingDepthRule(
        in: nil,
        stripLeadingProductRoot: true
    )

    public static func `domain nesting depth`(
        in repository: Institute.Repository.Coordinate?
    ) -> Lint.Rule {
        architectureDomainNestingDepthRule(in: repository, stripLeadingProductRoot: false)
    }
}

private func architectureDomainNestingDepthRule(
    in repository: Institute.Repository.Coordinate?,
    stripLeadingProductRoot: Swift::Bool
) -> Lint.Rule {
    Lint.Rule(
        id: "domain nesting depth",
        default: .warning,
        suppression: .both,
        controls: architectureDomainNestingDepthControls(in: repository, productRoot: stripLeadingProductRoot),
        observe: { source, severity in
            if let repository, repository.organization.layer == .standards {
                return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
            }
            guard let target = manifestSourceTarget(ofPath: source.file.filePath),
                !target.hasSuffix("Test Support"),
                !target.split(separator: " ").contains(where: { $0 == "Macro" || $0 == "Macros" })
            else {
                return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
            }
            let visitor = ArchitectureDomainNestingDepthVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter,
                stripLeadingProductRoot: stripLeadingProductRoot
            )
            visitor.walk(source.tree)
            return Lint.Rule.Observation(findings: visitor.matches, coverage: .measured)
        }
    )
}

private let architectureDepthTrailingCapabilities: Swift::Set<Swift::String> = [
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

private let architectureDepthTrailingSupport: Swift::Set<Swift::String> = [
    "Error",
    "Options",
    "Option",
    "Context",
    "State",
    "CodingKeys",
]

private let architectureDepthLeadingRoots: Swift::Set<Swift::String> = [
    "Linux",
    "Darwin",
    "Windows",
    "POSIX",
    "WHATWG",
    "W3C",
    "ISO",
    "IETF",
    "IEC",
    "IEEE",
    "ECMA",
    "BIPM",
    "INCITS",
    "NIST",
    "ITU",
    "SMPTE",
]

private func architectureDepthIsStandardRoot(_ segment: Swift::String) -> Swift::Bool {
    if architectureDepthLeadingRoots.contains(segment) { return true }
    let prefixes = ["ISO_", "RFC_", "IEC_", "ITU_", "FIPS_", "W3C_", "ECMA_", "IEEE_", "INCITS_", "BIPM_", "SMPTE_"]
    return prefixes.contains { segment.hasPrefix($0) }
}

private func architectureDomainNestingDepthControls(
    in repository: Institute.Repository.Coordinate?,
    productRoot: Swift::Bool
) -> [Lint.Rule.Control] {
    let name = repository?.name ?? "swift-demo"
    let root = "/workspace/\(name)"
    if let repository, repository.organization.layer == .standards {
        return [
            .init(
                id: "domain nesting depth standards exempt",
                source: "extension A.B.C {\n    public struct D {}\n}",
                path: "\(root)/Sources/Demo/A.B.C.D.swift",
                expectation: .clean,
                applicability: .inapplicable
            )
        ]
    }
    return [
        .init(
            id: "domain nesting depth three segments clean",
            source: "extension File.System {\n    public struct Read {}\n}",
            path: "\(root)/Sources/Demo/File.System.Read.swift",
            expectation: .clean
        ),
        .init(
            id: "domain nesting depth trailing support and capability excluded",
            source: "extension File.System.Read {\n    public struct Formatter {\n        public enum Error: Swift.Error {}\n    }\n}",
            path: "\(root)/Sources/Demo/File.System.Read.Formatter.swift",
            expectation: .clean
        ),
        .init(
            id: "domain nesting depth four domain segments flagged",
            source: productRoot
                ? "extension Product.A.B.C {\n    public struct D {}\n}"
                : "extension A.B.C {\n    public struct D {}\n}",
            path: "\(root)/Sources/Demo/A.B.C.D.swift",
            expectation: .findings(1)
        ),
        .init(
            id: "domain nesting depth leading standard root stripped",
            source: "extension ISO_9945.Kernel.File {\n    public struct Descriptor {}\n}",
            path: "\(root)/Sources/Demo/ISO_9945.Kernel.File.Descriptor.swift",
            expectation: .clean
        ),
        .init(
            id: "domain nesting depth tests exempt",
            source: "extension A.B.C {\n    public struct D {}\n}",
            path: "\(root)/Tests/Demo Tests/A.B.C.D.swift",
            expectation: .clean,
            applicability: .inapplicable
        ),
    ]
}

internal final class ArchitectureDomainNestingDepthVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    let stripLeadingProductRoot: Swift::Bool
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        stripLeadingProductRoot: Swift::Bool
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.stripLeadingProductRoot = stripLeadingProductRoot
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind {
        inspect(node.statements, prefix: [])
        return .skipChildren
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
        var domain = path[...]
        if stripLeadingProductRoot, !domain.isEmpty {
            domain = domain.dropFirst()
        } else if let first = domain.first, architectureDepthIsStandardRoot(first) {
            domain = domain.dropFirst()
        }
        while let last = domain.last, architectureDepthTrailingSupport.contains(last) {
            domain = domain.dropLast()
        }
        while let last = domain.last, architectureDepthTrailingCapabilities.contains(last) {
            domain = domain.dropLast()
        }
        guard domain.count >= 4 else { return }
        let full = path.joined(separator: ".")
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
                identifier: "domain nesting depth",
                message: "[domain nesting depth] [ARCH-PHRASE-004]: `\(full)` has \(domain.count) semantic "
                    + "domain segments (limit 3, excluding leading standard/product root and trailing capability or "
                    + "support suffixes). Flatten an intermediate namespace or extract a peer domain."
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
