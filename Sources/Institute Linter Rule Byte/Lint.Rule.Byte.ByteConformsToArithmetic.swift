public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `byte conforms to arithmetic protocol` = Lint.Rule(
        id: "byte conforms to arithmetic protocol",
        default: .error,
        controls: [
            .init(
                id: "byte conforms to arithmetic protocol Byte",
                source: "extension Byte: AdditiveArithmetic {}",
                path: "Sources/Byte Core/ByteArithmetic.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "byte conforms to arithmetic protocol Sendable",
                source: "extension Byte: Sendable {}",
                path: "Sources/Byte Core/ByteSendable.swift",
                expectation: .clean
            ),
            .init(
                id: "byte conforms to arithmetic protocol UInt8",
                source: "extension UInt8: AdditiveArithmetic {}",
                path: "Sources/Byte Core/UInt8Arithmetic.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ByteConformsToArithmeticVisitor(
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
internal let byteConformsToArithmeticMessage: Swift::String =
    "[byte conforms to arithmetic protocol] [API-BYTE-002]: `Byte` MUST "
    + "NOT conform to a stdlib arithmetic protocol. Per the byte-arithmetic "
    + "conformance note v1.0.0, `Byte` carries byte-domain identity, NOT "
    + "arithmetic. Migration paths: (a) if the rawValue participates in "
    + "arithmetic (`- 1`, `* 4`, modular roll-over), keep `rawValue: UInt8` "
    + "and bridge via `.underlying`; (b) if the rawValue is a bit-field / "
    + "kind-tag / opaque byte, retype storage to `Byte` and remove the "
    + "arithmetic conformance."

private let byteArithmeticProtocolNames: Swift::Set<Swift::String> = [
    "AdditiveArithmetic",
    "Numeric",
    "SignedNumeric",
    "BinaryInteger",
    "FixedWidthInteger",
    "SignedInteger",
    "UnsignedInteger",
    "Strideable",
]

internal final class ByteConformsToArithmeticVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let inheritance = node.inheritanceClause else { return .visitChildren }
        guard extensionIsOnByte(node.extendedType) else { return .visitChildren }
        for inherited in inheritance.inheritedTypes {
            guard arithmeticProtocolLeafName(inherited.type) != nil else { continue }
            emit(at: inherited.positionAfterSkippingLeadingTrivia)
        }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let inheritance = node.inheritanceClause else { return .visitChildren }
        guard Lint.Syntax.Identifier.unescaped(node.name.text) == "Byte" else {
            return .visitChildren
        }
        for inherited in inheritance.inheritedTypes {
            guard arithmeticProtocolLeafName(inherited.type) != nil else { continue }
            emit(at: inherited.positionAfterSkippingLeadingTrivia)
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
                identifier: "byte conforms to arithmetic protocol",
                message: byteConformsToArithmeticMessage
            )
        )
    }
}

internal func extensionIsOnByte(_ type: TypeSyntax) -> Swift::Bool {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(identifier.name.text) == "Byte"
    }
    if let memberType = type.as(MemberTypeSyntax.self) {
        guard Lint.Syntax.Identifier.unescaped(memberType.name.text) == "Byte" else { return false }
        if let base = memberType.baseType.as(IdentifierTypeSyntax.self) {
            return Lint.Syntax.Identifier.unescaped(base.name.text) == "Byte"
        }
        return false
    }
    return false
}

private func arithmeticProtocolLeafName(_ type: TypeSyntax) -> Swift::String? {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        let leaf = Lint.Syntax.Identifier.unescaped(identifier.name.text)
        if byteArithmeticProtocolNames.contains(leaf) {
            return leaf
        }
        return nil
    }
    if let memberType = type.as(MemberTypeSyntax.self) {
        let leaf = Lint.Syntax.Identifier.unescaped(memberType.name.text)
        if byteArithmeticProtocolNames.contains(leaf) {
            return leaf
        }
        return nil
    }
    return nil
}
