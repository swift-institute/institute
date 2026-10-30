public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `binary serializable rawvalue uint8` = Lint.Rule(
        id: "binary serializable rawvalue uint8",
        default: .warning,
        controls: [
            .init(
                id: "binary serializable rawvalue uint8 conformer",
                source: "public struct TypeOfService: Binary.Serializable { public let rawValue: UInt8 }",
                path: "Sources/Byte Core/ConformingUInt8.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "binary serializable rawvalue uint8 Byte",
                source: "public struct TypeOfService: Binary.Serializable { public let rawValue: Byte }",
                path: "Sources/Byte Core/ConformingByte.swift",
                expectation: .clean
            ),
            .init(
                id: "binary serializable rawvalue uint8 nonconforming",
                source: "public struct TypeOfService { public let rawValue: UInt8 }",
                path: "Sources/Byte Core/NonconformingUInt8.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ByteBinarySerializableRawValueUInt8Visitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let byteBinarySerializableRawValueUInt8Message: Swift::String =
    "[binary serializable rawvalue uint8] [API-BYTE-004]: type conforms "
    + "to `Binary.Serializable` / `Binary.Parseable` and stores "
    + "`rawValue: UInt8`. Per the W2 discrimination rubric (broader-l2-l3"
    + "-byte-typing-gap-plan.md § Wave 2): if rawValue participates in "
    + "arithmetic, KEEP `UInt8` and bridge via `.underlying`; if it's a "
    + "bit-field / kind-tag / opaque byte, RETYPE storage to `Byte`."

internal final class ByteBinarySerializableRawValueUInt8Visitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    private var conformingTypePaths: Swift::Set<Swift::String> = []
    private var typesWithRawValueUInt8: [(path: Swift::String, position: AbsolutePosition)] = []
    private var enclosingPath: [Swift::String] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    private var currentQualifiedPath: Swift::String { enclosingPath.joined(separator: ".") }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingPath.append(Lint.Syntax.Identifier.unescaped(node.name.text))
        recordTypeDecl(inheritance: node.inheritanceClause)
        recordRawValueUInt8(members: node.memberBlock)
        return .visitChildren
    }
    override func visitPost(_: StructDeclSyntax) { _ = enclosingPath.popLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingPath.append(Lint.Syntax.Identifier.unescaped(node.name.text))
        recordTypeDecl(inheritance: node.inheritanceClause)
        recordRawValueUInt8(members: node.memberBlock)
        return .visitChildren
    }
    override func visitPost(_: EnumDeclSyntax) { _ = enclosingPath.popLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingPath.append(Lint.Syntax.Identifier.unescaped(node.name.text))
        recordTypeDecl(inheritance: node.inheritanceClause)
        recordRawValueUInt8(members: node.memberBlock)
        return .visitChildren
    }
    override func visitPost(_: ClassDeclSyntax) { _ = enclosingPath.popLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingPath.append(Lint.Syntax.Identifier.unescaped(node.name.text))
        recordTypeDecl(inheritance: node.inheritanceClause)
        recordRawValueUInt8(members: node.memberBlock)
        return .visitChildren
    }
    override func visitPost(_: ActorDeclSyntax) { _ = enclosingPath.popLast() }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        if let inheritance = node.inheritanceClause,
            inheritanceContainsSerializableLikeProtocol(inheritance),
            let typeName = byteExtensionExtendedLeafName(node.extendedType)
        {
            conformingTypePaths.insert(typeName)
        }
        return .visitChildren
    }

    private func recordTypeDecl(inheritance: InheritanceClauseSyntax?) {
        if let inheritance, inheritanceContainsSerializableLikeProtocol(inheritance) {
            conformingTypePaths.insert(currentQualifiedPath)
        }
    }

    private func recordRawValueUInt8(members: MemberBlockSyntax) {
        let path = currentQualifiedPath
        for member in members.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            for binding in variable.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                    continue
                }
                if Lint.Syntax.Identifier.unescaped(pattern.identifier.text) != "rawValue" {
                    continue
                }
                guard let typeAnnotation = binding.typeAnnotation else { continue }
                if byteTypeAnnotationIsUInt8(typeAnnotation.type) {
                    typesWithRawValueUInt8.append(
                        (path, pattern.identifier.positionAfterSkippingLeadingTrivia)
                    )
                }
            }
        }
    }

    override func visitPost(_ node: SourceFileSyntax) {
        for entry in typesWithRawValueUInt8 where conformingTypePaths.contains(entry.path) {
            let location = converter.location(for: entry.position)
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "binary serializable rawvalue uint8",
                    message: byteBinarySerializableRawValueUInt8Message
                )
            )
        }
    }
}

internal func byteTypeAnnotationIsUInt8(_ type: TypeSyntax) -> Swift::Bool {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(identifier.name.text) == "UInt8"
    }
    if let memberType = type.as(MemberTypeSyntax.self) {
        let leaf = Lint.Syntax.Identifier.unescaped(memberType.name.text)
        guard leaf == "UInt8" else { return false }
        if let base = memberType.baseType.as(IdentifierTypeSyntax.self) {
            return Lint.Syntax.Identifier.unescaped(base.name.text) == "Swift"
        }
        return false
    }
    return false
}

internal func inheritanceContainsSerializableLikeProtocol(
    _ clause: InheritanceClauseSyntax
)
    -> Swift::Bool
{
    for inherited in clause.inheritedTypes {
        if byteTypeIsSerializableLike(inherited.type) {
            return true
        }
    }
    return false
}

internal func byteTypeIsSerializableLike(_ type: TypeSyntax) -> Swift::Bool {
    guard let memberType = type.as(MemberTypeSyntax.self) else { return false }
    let trailingName = Lint.Syntax.Identifier.unescaped(memberType.name.text)
    guard trailingName == "Serializable" || trailingName == "Parseable" else { return false }
    if let identifier = memberType.baseType.as(IdentifierTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(identifier.name.text) == "Binary"
    }
    if let nestedMember = memberType.baseType.as(MemberTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(nestedMember.name.text) == "Binary"
    }
    return false
}

internal func byteExtensionExtendedLeafName(_ type: TypeSyntax) -> Swift::String? {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(identifier.name.text)
    }
    if let memberType = type.as(MemberTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(memberType.name.text)
    }
    return nil
}
