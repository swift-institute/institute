internal import Institute_Linter_Rule_Manifest
public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `extension file naming` = Lint.Rule(
        id: "extension file naming",
        default: .warning,
        controls: [
            .init(
                id: "extension file naming upstream licensed package",
                source: "extension Array.Dynamic { func iterate() {} }",
                path: "Sources/Structure Core/Array.Dynamic+Iteration.swift",
                expectation: .clean,
                license: .text("MIT License\n\nCopyright (c) 2025 Point-Free, Inc.\n\nPermission is hereby granted")
            ),
            .init(
                id: "extension file naming apache with upstream notice",
                source: "extension Array.Dynamic { func iterate() {} }",
                path: "Sources/Structure Core/Array.Dynamic+Iteration.swift",
                expectation: .findings(1),
                license: .text(manifestApacheLicenseTerms + "\n\nCopyright (c) 2019 Point-Free, Inc.\n\nPermission is hereby granted")
            ),
            .init(
                id: "extension file naming own licensed package",
                source: "extension Array.Dynamic { func iterate() {} }",
                path: "Sources/Structure Core/Array.Dynamic+Iteration.swift",
                expectation: .findings(1),
                license: .text("MIT License\n\nCopyright (c) 2026 Swift Institute\n\nPermission is hereby granted")
            ),
            .init(
                id: "extension file naming own module selector",
                source: "extension Cyclic::Cyclic.Group { func iterate() {} }",
                path: "Sources/Structure Core/Cyclic.Group.swift",
                expectation: .clean
            ),
            .init(
                id: "extension file naming module selector own file",
                source: "extension Swift::Array { func iterate() {} }",
                path: "Sources/Structure Core/Swift.Array.swift",
                expectation: .clean
            ),
            .init(
                id: "extension file naming member own file",
                source: "extension Array.Dynamic { func iterate() {} }",
                path: "Sources/Structure Core/Array.Dynamic.swift",
                expectation: .clean
            ),
            .init(
                id: "extension file naming generic specialisation own file",
                source: "extension Binding<Reminder> { func dueOn() {} }",
                path: "Sources/Structure Core/Binding<Reminder>.swift",
                expectation: .clean
            ),
            .init(
                id: "extension file naming member topic",
                source: "extension Array.Dynamic { func iterate() {} }",
                path: "Sources/Structure Core/Array.Dynamic+Iteration.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "extension file naming conversion owner",
                source: "extension Algebra.Magma { init(_ group: Algebra.Group<Element>) {} }",
                path: "Sources/Algebra Group/Algebra.Group+Algebra.Magma.swift",
                expectation: .clean
            ),
            .init(
                id: "extension file naming stdlib conformance relocation",
                source: "extension Array.Dynamic: Sendable {}",
                path: "Sources/Structure Core/Array.Dynamic+Sendable.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "extension file naming test scope",
                source: "extension Array.Dynamic { func iterate() {} }",
                path: "Tests/Structure Tests/Array.Dynamic.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            if manifestLicenseIsUpstream(source.index.license) { return [] }
            let path = source.file.filePath
            guard path.hasPrefix("Sources/") || path.contains("/Sources/") else {
                return []
            }
            for excluded in ["Tests", "Experiments", "Examples"] {
                if path == excluded
                    || path.hasPrefix("\(excluded)/")
                    || path.contains("/\(excluded)/")
                {
                    return []
                }
            }
            return structureExtensionFileNamingFindings(
                path: path,
                source: source.file,
                severity: severity,
                converter: source.converter,
                tree: source.tree
            )
        }
    )
}

private func structureExtensionFileNamingFindings(
    path: Swift::String,
    source: Source.File,
    severity: Diagnostic.Severity,
    converter: SourceLocationConverter,
    tree: SourceFileSyntax
) -> [Diagnostic.Record] {
    let filename: Swift::String =
        if let slashIndex = path.lastIndex(of: "/") {
            Swift::String(path[path.index(after: slashIndex)...])
        } else {
            path
        }
    guard filename.hasSuffix(".swift") else { return [] }
    let basename = Swift::String(filename.dropLast(".swift".count))

    let collector = StructureExtensionFileNamingCollector()
    collector.walk(tree)

    guard !collector.hasPrimaryType else { return [] }
    guard let first = collector.extensions.first else { return [] }

    let location = converter.location(for: first.extendedType.positionAfterSkippingLeadingTrivia)

    func record(_ message: Swift::String) -> [Diagnostic.Record] {
        [
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "extension file naming",
                message: message
            )
        ]
    }

    let bases = Swift::Set(
        collector.extensions.map { structureExtensionFileNamingBaseKey($0.extendedType) }
    )
    let base = structureExtensionFileNamingBaseKey(first.extendedType)
    guard bases.count == 1 else {
        return record(
            structureExtensionFileNamingMixedBaseMessage(basename: basename, bases: bases)
        )
    }

    if collector.extensions.allSatisfy(structureIsStdlibOnlyConformanceExtension) {
        return record(
            structureExtensionFileNamingStdlibConformanceMessage(basename: basename, base: base)
        )
    }
    let conformances = collector.extensions.flatMap { extensionDecl -> [Swift::String] in
        guard let clause = extensionDecl.inheritanceClause else { return [] }
        return clause.inheritedTypes.compactMap {
            structureDottedName(of: $0.type).map(Lint.Syntax.Identifier.unescaped)
        }
        .filter { !structureIsStdlibConformance($0) }
    }
    let hasWhere = collector.extensions.contains { $0.genericWhereClause != nil }

    if !conformances.isEmpty {
        let conformancePrefix = "\(base)+"
        if basename.hasPrefix(conformancePrefix) {
            let candidate = Swift::String(basename.dropFirst(conformancePrefix.count))
            if conformances.contains(where: {
                structureExtensionFileNamingConformanceMatches(
                    candidate: candidate,
                    conformance: $0
                )
            }) {
                return []
            }
        }
        return record(
            structureExtensionFileNamingConformanceMessage(
                basename: basename,
                base: base,
                conformance: conformances[0]
            )
        )
    }

    if hasWhere {
        let prefix = "\(base) where "
        if basename.hasPrefix(prefix), basename.count > prefix.count {
            return []
        }
        return record(structureExtensionFileNamingWhereMessage(basename: basename, base: base))
    }

    if basename == base {
        return []
    }
    if collector.extensions.allSatisfy({ structureModuleSpelling($0.extendedType.trimmedDescription) == basename }) {
        return []
    }
    if structureExtensionFileNamingIsConversionOwned(
        basename: basename,
        extendedBase: base,
        extensions: collector.extensions
    ) {
        return []
    }
    return record(structureExtensionFileNamingOwnFileMessage(basename: basename, base: base))
}

@usableFromInline
internal func structureExtensionFileNamingMixedBaseMessage(
    basename: Swift::String,
    bases: Swift::Set<Swift::String>
) -> Swift::String {
    let sorted = bases.sorted().joined(separator: "', '")
    return "[extension file naming] [API-IMPL-007]: extension file '\(basename).swift' mixes "
        + "extensions on different base types ('\(sorted)'); a mixed-base extension file has "
        + "no lawful name — split into one file per base type."
}

@usableFromInline
internal func structureExtensionFileNamingStdlibConformanceMessage(
    basename: Swift::String,
    base: Swift::String
) -> Swift::String {
    "[extension file naming] [API-IMPL-007]: extension file '\(basename).swift' adds only "
        + "standard-library conformances; those stay in the type's own file '\(base).swift' as "
        + "extensions directly under the type declaration (e.g. `extension \(base): Sendable {}`), "
        + "never in a '+<Conformance>' sibling file — move the extension(s) there"
}

@usableFromInline
internal func structureExtensionFileNamingConformanceMessage(
    basename: Swift::String,
    base: Swift::String,
    conformance: Swift::String
) -> Swift::String {
    "[extension file naming] [API-IMPL-007]: extension file '\(basename).swift' must be named "
        + "'\(base)+\(conformance).swift' for the conformance it adds"
}

@usableFromInline
internal func structureExtensionFileNamingWhereMessage(
    basename: Swift::String,
    base: Swift::String
) -> Swift::String {
    "[extension file naming] [API-IMPL-007]: extension file '\(basename).swift' must use the "
        + "'\(base) where <discriminator>.swift' shape"
}

@usableFromInline
internal func structureExtensionFileNamingOwnFileMessage(
    basename: Swift::String,
    base: Swift::String
) -> Swift::String {
    "[extension file naming] [API-IMPL-007]: extension file '\(basename).swift' holds "
        + "member-only extensions of '\(base)'; those live in the type's own file "
        + "'\(base).swift' (merge into it when the type is declared in this module; a "
        + "generic specialisation keeps its arguments, e.g. 'Binding<Reminder>.swift'), or, "
        + "for a conversion initializer, in '<Owner>+\(base).swift' with a parameter of "
        + "that owner type. A '+' segment names a type, never a topic"
}

private func structureExtensionFileNamingIsConversionOwned(
    basename: Swift::String,
    extendedBase: Swift::String,
    extensions: [ExtensionDeclSyntax]
) -> Swift::Bool {
    let suffix = "+\(extendedBase)"
    guard basename.hasSuffix(suffix), basename.count > suffix.count else { return false }
    let owner = Swift::String(basename.dropLast(suffix.count))

    for extensionDecl in extensions {
        for member in extensionDecl.memberBlock.members {
            guard let initializer = member.decl.as(InitializerDeclSyntax.self) else { continue }
            for parameter in initializer.signature.parameterClause.parameters
            where structureDottedName(of: parameter.type) == owner {
                return true
            }
        }
    }
    return false
}

private final class StructureExtensionFileNamingCollector: SyntaxVisitor {
    var extensions: [ExtensionDeclSyntax] = []
    var hasPrimaryType: Swift::Bool = false

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind {
        for item in Lint.Syntax.Conditional.statements(node.statements) {
            guard case .decl(let decl) = item.item else { continue }
            if let extensionDecl = decl.as(ExtensionDeclSyntax.self) {
                extensions.append(extensionDecl)
                for member in extensionDecl.memberBlock.members
                where structureExtensionFileNamingIsPrimaryTypeDecl(member.decl) {
                    hasPrimaryType = true
                }
                continue
            }
            if structureExtensionFileNamingIsPrimaryTypeDecl(decl) {
                hasPrimaryType = true
            }
        }
        return .skipChildren
    }
}

private func structureExtensionFileNamingBaseKey(_ type: TypeSyntax) -> Swift::String {
    structureDottedName(of: type) ?? type.trimmedDescription
}

private func structureExtensionFileNamingConformanceMatches(
    candidate: Swift::String,
    conformance: Swift::String
) -> Swift::Bool {
    if candidate == conformance { return true }
    return conformance.hasSuffix(".\(candidate)")
}

private func structureExtensionFileNamingIsPrimaryTypeDecl(_ decl: DeclSyntax) -> Swift::Bool {
    decl.is(StructDeclSyntax.self)
        || decl.is(ClassDeclSyntax.self)
        || decl.is(EnumDeclSyntax.self)
        || decl.is(ActorDeclSyntax.self)
        || decl.is(ProtocolDeclSyntax.self)
}
