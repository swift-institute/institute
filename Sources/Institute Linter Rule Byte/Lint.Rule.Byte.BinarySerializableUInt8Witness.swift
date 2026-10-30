public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `binary serializable uint8 witness` = Lint.Rule(
        id: "binary serializable uint8 witness",
        default: .error,
        controls: [
            .init(
                id: "binary serializable uint8 witness UInt8",
                source: "extension Foo: Binary.Serializable { public static func "
                    + "serialize<Buffer: RangeReplaceableCollection>(_ value: Self, into buffer: inout Buffer) where Buffer.Element == UInt8 {} }",
                path: "Sources/Byte Core/UInt8Witness.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "binary serializable uint8 witness Byte",
                source: "extension Foo: Binary.Serializable { public static func "
                    + "serialize<Buffer: RangeReplaceableCollection>(_ value: Self, into buffer: inout Buffer) where Buffer.Element == Byte {} }",
                path: "Sources/Byte Core/ByteWitness.swift",
                expectation: .clean
            ),
            .init(
                id: "binary serializable uint8 witness outside context",
                source: "extension Array { public static func serialize<Buffer: RangeReplaceableCollection>(_ value: Self, into buffer: inout Buffer) where Buffer.Element == UInt8 {} }",
                path: "Sources/Byte Core/OutsideWitness.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ByteBinarySerializableUInt8WitnessVisitor(
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
internal let byteBinarySerializableUInt8WitnessMessage: Swift::String =
    "[binary serializable uint8 witness] [API-BYTE-003]: `Binary."
    + "Serializable` / `Binary.Parseable` witness uses `Buffer.Element == "
    + "UInt8` (or `Source.Element == UInt8`). The protocol surface is now "
    + "Byte-typed (Wave 2, swift-binary@b121c0e). Retype the "
    + "where-clause to `== Byte`. If this is a stdlib-interop forwarder, "
    + "add `@_disfavoredOverload` per [API-BYTE-006]."

private let byteSerializableLikeProtocolPairs: [(host: Swift::String, name: Swift::String)] = [
    ("Binary", "Serializable"),
    ("Binary", "Parseable"),
]

private let byteWitnessElementTypeParameterNames: Swift::Set<Swift::String> = [
    "Buffer",
    "Bytes",
    "Source",
    "Sequence",
    "Collection",
]

internal final class ByteBinarySerializableUInt8WitnessVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    private var contextStack: [Swift::Bool] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let isQualifying = extensionConformsToSerializableLike(node)
        contextStack.append(isQualifying)
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        if !contextStack.isEmpty {
            contextStack.removeLast()
        }
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard contextStack.last == true else { return .visitChildren }
        let baseName = Lint.Syntax.Identifier.unescaped(node.name.text)
        guard byteWitnessFunctionNames.contains(baseName) else { return .visitChildren }
        if byteFunctionHasDisfavoredOverload(node.attributes) {
            return .visitChildren
        }
        guard let whereClause = node.genericWhereClause else { return .visitChildren }
        for requirement in whereClause.requirements {
            if byteRequirementIsElementEqualsUInt8(requirement) {
                emit(at: requirement.positionAfterSkippingLeadingTrivia)
                return .visitChildren
            }
        }
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard contextStack.last == true else { return .visitChildren }
        if byteFunctionHasDisfavoredOverload(node.attributes) {
            return .visitChildren
        }
        guard let whereClause = node.genericWhereClause else { return .visitChildren }
        for requirement in whereClause.requirements {
            if byteRequirementIsElementEqualsUInt8(requirement) {
                emit(at: requirement.positionAfterSkippingLeadingTrivia)
                return .visitChildren
            }
        }
        return .visitChildren
    }

    private func emit(at position: AbsolutePosition) {
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
                identifier: "binary serializable uint8 witness",
                message: byteBinarySerializableUInt8WitnessMessage
            )
        )
    }
}

internal let byteWitnessFunctionNames: Swift::Set<Swift::String> = [
    "serialize",
    "parse",
    "init",
]

internal func extensionConformsToSerializableLike(_ node: ExtensionDeclSyntax) -> Swift::Bool {
    if let inheritance = node.inheritanceClause {
        for inherited in inheritance.inheritedTypes {
            if byteTypeMatchesSerializableLike(inherited.type) {
                return true
            }
        }
    }
    if byteTypeMatchesSerializableLike(node.extendedType) {
        return true
    }
    return false
}

private func byteTypeMatchesSerializableLike(_ type: TypeSyntax) -> Swift::Bool {
    guard let memberType = type.as(MemberTypeSyntax.self) else { return false }
    let trailingName = Lint.Syntax.Identifier.unescaped(memberType.name.text)
    guard let rootName = byteRootIdentifierName(memberType.baseType) else { return false }
    for pair in byteSerializableLikeProtocolPairs
    where pair.host == rootName && pair.name == trailingName {
        return true
    }
    return false
}

private func byteRootIdentifierName(_ type: TypeSyntax) -> Swift::String? {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(identifier.name.text)
    }
    if let memberType = type.as(MemberTypeSyntax.self) {
        return byteRootIdentifierName(memberType.baseType)
    }
    return nil
}

internal func byteFunctionHasDisfavoredOverload(_ attributes: AttributeListSyntax) -> Swift::Bool {
    for element in attributes {
        guard let attribute = element.as(AttributeSyntax.self) else { continue }
        guard let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self) else {
            continue
        }
        if Lint.Syntax.Identifier.unescaped(identifier.name.text) == "_disfavoredOverload" {
            return true
        }
    }
    return false
}

private func byteRequirementIsElementEqualsUInt8(
    _ requirement: GenericRequirementSyntax
)
    -> Swift::Bool
{
    guard let sameType = requirement.requirement.as(SameTypeRequirementSyntax.self) else {
        return false
    }
    let left = sameType.leftType.trimmedDescription
    let right = sameType.rightType.trimmedDescription
    let leftIsElement: Swift::Bool = {
        let parts = left.split(separator: ".")
        guard parts.count == 2 else { return false }
        guard Lint.Syntax.Identifier.unescaped(Swift::String(parts[1])) == "Element" else {
            return false
        }
        return byteWitnessElementTypeParameterNames.contains(
            Lint.Syntax.Identifier.unescaped(Swift::String(parts[0]))
        )
    }()
    guard leftIsElement else { return false }
    return right == "UInt8" || right == "Swift.UInt8"
}
