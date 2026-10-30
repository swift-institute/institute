internal import Institute_Linter_Rule_Manifest
public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `file name nested path` = Lint.Rule(
        id: "file name nested path",
        default: .warning,
        controls: [
            .init(
                id: "file name nested path upstream licensed package",
                source: "enum Array { struct Dynamic {} }",
                path: "Sources/Structure Core/Array.swift",
                expectation: .clean,
                license: .text("MIT License\n\nCopyright (c) 2025 Point-Free, Inc.\n\nPermission is hereby granted")
            ),
            .init(
                id: "file name nested path own module selector",
                source: "extension Cyclic::Cyclic.Group { public struct Modulus { public let value: Int } }",
                path: "Sources/Cyclic/Cyclic.Group.Modulus.swift",
                expectation: .clean
            ),
            .init(
                id: "file name nested path stdlib module selector",
                source: "extension Swift::String { public struct Coder { public let value: Int } }",
                path: "Sources/Coder/Swift.String.Coder.swift",
                expectation: .clean
            ),
            .init(
                id: "file name nested path mismatched basename",
                source: "enum Array { struct Dynamic {} }",
                path: "Sources/Structure Core/Array.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "file name nested path matching basename",
                source: "enum Array { struct Dynamic {} }",
                path: "Sources/Structure Core/Array.Dynamic.swift",
                expectation: .clean
            ),
            .init(
                id: "file name nested path test scope",
                source: "enum Array { struct Dynamic {} }",
                path: "Tests/Structure Tests/Array.swift",
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
            guard let slashIndex = path.lastIndex(of: "/") else {
                return structureFileNameNestedPathFindings(
                    basename: path,
                    source: source.file,
                    severity: severity,
                    converter: source.converter,
                    tree: source.tree
                )
            }
            let filename = Swift::String(path[path.index(after: slashIndex)...])
            return structureFileNameNestedPathFindings(
                basename: filename,
                source: source.file,
                severity: severity,
                converter: source.converter,
                tree: source.tree
            )
        }
    )
}

private func structureFileNameNestedPathFindings(
    basename filename: Swift::String,
    source: Source.File,
    severity: Diagnostic.Severity,
    converter: SourceLocationConverter,
    tree: SourceFileSyntax
) -> [Diagnostic.Record] {
    guard filename.hasSuffix(".swift") else { return [] }
    let basename = Swift::String(filename.dropLast(".swift".count))

    if basename.contains("+") || basename.contains(" where ") { return [] }

    let collector = Collector()
    collector.walk(tree)

    guard collector.primaryTypes.count == 1 else { return [] }
    let primary = collector.primaryTypes[0]

    let resolvedOwnPath = structureFileNameNestedPathResolve(primary.node)
    var dottedPath =
        primary.extensionPrefix.isEmpty
        ? resolvedOwnPath
        : "\(primary.extensionPrefix).\(resolvedOwnPath)"

    if let protocolDecl = primary.node.as(ProtocolDeclSyntax.self) {
        let protocolName = protocolDecl.name.text
        for extensionDecl in collector.topLevelExtensions {
            guard
                let carrierPath = structureDottedName(
                    of: extensionDecl.extendedType
                )
            else { continue }
            for member in extensionDecl.memberBlock.members {
                guard let alias = member.decl.as(TypeAliasDeclSyntax.self) else { continue }
                guard Lint.Syntax.Identifier.unescaped(alias.name.text) == "Protocol" else {
                    continue
                }
                guard
                    let aliasedName = structureDottedName(of: alias.initializer.value)
                else { continue }
                guard aliasedName == protocolName else { continue }
                dottedPath = "\(carrierPath).Protocol"
            }
        }
    }

    guard basename != dottedPath else { return [] }

    let wrappingPosition = primary.wrappingExtension?.position
    let others = collector.topLevelExtensions.filter { $0.position != wrappingPosition }
    if !others.isEmpty {
        let allDiscriminated = others.allSatisfy { extensionDecl in
            let hasConformance =
                extensionDecl.inheritanceClause.map { !$0.inheritedTypes.isEmpty } ?? false
            let hasWhere = extensionDecl.genericWhereClause != nil
            let staysWithType =
                !hasWhere && structureIsStdlibOnlyConformanceExtension(extensionDecl)
            return (hasConformance || hasWhere) && !staysWithType
        }
        if allDiscriminated { return [] }
    }

    let location = converter.location(for: primary.namePosition)
    return [
        Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "file name nested path",
            message: structureFileNameNestedPathMessage(basename: basename, dottedPath: dottedPath)
        )
    ]
}

@usableFromInline
internal func structureFileNameNestedPathMessage(
    basename: Swift::String,
    dottedPath: Swift::String
) -> Swift::String {
    "[file name nested path] [API-IMPL-006]: file name '\(basename).swift' does not match "
        + "the declared type's nested path '\(dottedPath)'; rename to '\(dottedPath).swift'"
}

private func structureFileNameNestedPathResolve(_ node: DeclSyntax) -> Swift::String {
    guard let enumDecl = node.as(EnumDeclSyntax.self) else {
        return structureFileNameNestedPathOwnName(node) ?? ""
    }
    var nestedTypes: [DeclSyntax] = []
    for member in enumDecl.memberBlock.members {
        if member.decl.is(EnumCaseDeclSyntax.self) {
            return enumDecl.name.text
        }
        if member.decl.is(TypeAliasDeclSyntax.self) { continue }
        if structureFileNameNestedPathIsPrimaryTypeDecl(member.decl) {
            nestedTypes.append(member.decl)
            continue
        }
        return enumDecl.name.text
    }
    guard nestedTypes.count == 1 else {
        return enumDecl.name.text
    }
    return "\(enumDecl.name.text).\(structureFileNameNestedPathResolve(nestedTypes[0]))"
}

private func structureFileNameNestedPathIsPrimaryTypeDecl(_ declaration: DeclSyntax) -> Swift::Bool {
    declaration.is(StructDeclSyntax.self)
        || declaration.is(ClassDeclSyntax.self)
        || declaration.is(EnumDeclSyntax.self)
        || declaration.is(ActorDeclSyntax.self)
        || declaration.is(ProtocolDeclSyntax.self)
}

private func structureFileNameNestedPathOwnName(_ node: DeclSyntax) -> Swift::String? {
    if let d = node.as(StructDeclSyntax.self) { return d.name.text }
    if let d = node.as(ClassDeclSyntax.self) { return d.name.text }
    if let d = node.as(ActorDeclSyntax.self) { return d.name.text }
    if let d = node.as(ProtocolDeclSyntax.self) { return d.name.text }
    if let d = node.as(EnumDeclSyntax.self) { return d.name.text }
    return nil
}

internal func isPrimary(_ decl: DeclSyntax) -> Swift::Bool {
    if let classDecl = decl.as(ClassDeclSyntax.self) {
        if structureExtendsSyntaxVisitor(classDecl.inheritanceClause) { return false }
        return true
    }
    return decl.is(StructDeclSyntax.self)
        || decl.is(EnumDeclSyntax.self)
        || decl.is(ActorDeclSyntax.self)
        || decl.is(ProtocolDeclSyntax.self)
}

internal func position(of node: DeclSyntax) -> AbsolutePosition {
    if let d = node.as(StructDeclSyntax.self) { return d.name.positionAfterSkippingLeadingTrivia }
    if let d = node.as(ClassDeclSyntax.self) { return d.name.positionAfterSkippingLeadingTrivia }
    if let d = node.as(EnumDeclSyntax.self) { return d.name.positionAfterSkippingLeadingTrivia }
    if let d = node.as(ActorDeclSyntax.self) { return d.name.positionAfterSkippingLeadingTrivia }
    if let d = node.as(ProtocolDeclSyntax.self) { return d.name.positionAfterSkippingLeadingTrivia }
    return node.positionAfterSkippingLeadingTrivia
}
