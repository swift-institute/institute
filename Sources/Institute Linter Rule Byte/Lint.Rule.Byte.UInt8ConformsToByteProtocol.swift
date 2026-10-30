public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `uint8 conforms to byte protocol` = Lint.Rule(
        id: "uint8 conforms to byte protocol",
        default: .error,
        controls: [
            .init(
                id: "uint8 conforms to byte protocol UInt8",
                source: "extension UInt8: Byte.`Protocol` {}",
                path: "Sources/Byte Core/UInt8Conformance.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "uint8 conforms to byte protocol Sendable",
                source: "extension UInt8: Sendable {}",
                path: "Sources/Byte Core/SendableConformance.swift",
                expectation: .clean
            ),
            .init(
                id: "uint8 conforms to byte protocol Byte",
                source: "extension Byte: Byte.`Protocol` {}",
                path: "Sources/Byte Core/ByteConformance.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ByteUInt8ConformsToByteProtocolVisitor(
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
internal let byteUInt8ConformsToByteProtocolMessage: Swift::String =
    "[uint8 conforms to byte protocol] [API-BYTE-001]: `UInt8` MUST NOT "
    + "conform to `Byte.\\`Protocol\\``. The stdlib raw arithmetic carrier "
    + "(`UInt8`) and the institute byte-domain twin (`Byte`) are sibling-"
    + "form per the byte-protocol capability-marker note v1.1.0; adding the "
    + "conformance dissolves the separation. Either remove the conformance "
    + "or migrate consumers to `Byte` substrate."

internal final class ByteUInt8ConformsToByteProtocolVisitor: SyntaxVisitor {
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
        guard extensionIsOnUInt8(node.extendedType) else { return .visitChildren }
        guard inheritanceContainsByteProtocol(inheritance) else { return .visitChildren }
        emit(at: node.extensionKeyword.positionAfterSkippingLeadingTrivia)
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
                identifier: "uint8 conforms to byte protocol",
                message: byteUInt8ConformsToByteProtocolMessage
            )
        )
    }
}

internal func extensionIsOnUInt8(_ type: TypeSyntax) -> Swift::Bool {
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

private func inheritanceContainsByteProtocol(_ clause: InheritanceClauseSyntax) -> Swift::Bool {
    for inherited in clause.inheritedTypes {
        if byteTypeIsByteProtocol(inherited.type) {
            return true
        }
    }
    return false
}

internal func byteTypeIsByteProtocol(_ type: TypeSyntax) -> Swift::Bool {
    guard let memberType = type.as(MemberTypeSyntax.self) else { return false }
    let trailingName = Lint.Syntax.Identifier.unescaped(memberType.name.text)
    guard trailingName == "Protocol" else { return false }
    if let identifier = memberType.baseType.as(IdentifierTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(identifier.name.text) == "Byte"
    }
    if let nestedMember = memberType.baseType.as(MemberTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(nestedMember.name.text) == "Byte"
    }
    return false
}
