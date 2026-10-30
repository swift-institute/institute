public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `uint8 ascii extension` = Lint.Rule(
        id: "uint8 ascii extension",
        default: .warning,
        controls: [
            .init(
                id: "uint8 ascii extension UInt8 namespace",
                source: "extension UInt8 { static var ascii: Self { 0 } }",
                path: "Sources/Byte Core/UInt8ASCII.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "uint8 ascii extension ASCII Code",
                source: "extension ASCII.Code { static let lf: ASCII.Code = 0x0A }",
                path: "Sources/Byte Core/ASCIICode.swift",
                expectation: .clean
            ),
            .init(
                id: "uint8 ascii extension unrelated member",
                source: "extension UInt8 { static var zero: Self { 0 } }",
                path: "Sources/Byte Core/UInt8Zero.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ByteUInt8AsciiExtensionVisitor(
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
internal let byteUInt8AsciiExtensionMessage: Swift::String =
    "[uint8 ascii extension] [API-BYTE-005]: `extension UInt8` declares "
    + "members under the `.ascii` namespace (or extends `UInt8.ASCII` "
    + "directly). The `UInt8+ASCII.swift` wrapper is phased out in Wave 4 "
    + "of the broader L2/L3 byte-typing arc. Migrate consumers to "
    + "`ASCII.Code` substrate (e.g., `ASCII.Code.lf` instead of "
    + "`UInt8.ascii.lf`)."

internal final class ByteUInt8AsciiExtensionVisitor: SyntaxVisitor {
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
        if extensionExtendsUInt8DotASCII(node.extendedType) {
            emit(at: node.extensionKeyword.positionAfterSkippingLeadingTrivia)
            return .visitChildren
        }
        if extensionIsOnUInt8(node.extendedType),
            memberBlockDeclaresAsciiNamespaceMember(node.memberBlock)
        {
            emit(at: node.extensionKeyword.positionAfterSkippingLeadingTrivia)
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
                identifier: "uint8 ascii extension",
                message: byteUInt8AsciiExtensionMessage
            )
        )
    }
}

private func extensionExtendsUInt8DotASCII(_ type: TypeSyntax) -> Swift::Bool {
    guard let memberType = type.as(MemberTypeSyntax.self) else { return false }
    let trailing = Lint.Syntax.Identifier.unescaped(memberType.name.text)
    guard trailing == "ASCII" else { return false }
    if let identifier = memberType.baseType.as(IdentifierTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(identifier.name.text) == "UInt8"
    }
    if let nestedMember = memberType.baseType.as(MemberTypeSyntax.self) {
        let nestedTrailing = Lint.Syntax.Identifier.unescaped(nestedMember.name.text)
        guard nestedTrailing == "UInt8" else { return false }
        if let swiftBase = nestedMember.baseType.as(IdentifierTypeSyntax.self) {
            return Lint.Syntax.Identifier.unescaped(swiftBase.name.text) == "Swift"
        }
        return false
    }
    return false
}

private func memberBlockDeclaresAsciiNamespaceMember(_ block: MemberBlockSyntax) -> Swift::Bool {
    for member in block.members {
        if let variable = member.decl.as(VariableDeclSyntax.self) {
            for binding in variable.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                    continue
                }
                if Lint.Syntax.Identifier.unescaped(pattern.identifier.text) == "ascii" {
                    return true
                }
            }
        }
        if let function = member.decl.as(FunctionDeclSyntax.self) {
            if Lint.Syntax.Identifier.unescaped(function.name.text) == "ascii" {
                return true
            }
        }
        if let nestedEnum = member.decl.as(EnumDeclSyntax.self) {
            if Lint.Syntax.Identifier.unescaped(nestedEnum.name.text) == "ASCII" {
                return true
            }
        }
        if let nestedStruct = member.decl.as(StructDeclSyntax.self) {
            if Lint.Syntax.Identifier.unescaped(nestedStruct.name.text) == "ASCII" {
                return true
            }
        }
        if let nestedClass = member.decl.as(ClassDeclSyntax.self) {
            if Lint.Syntax.Identifier.unescaped(nestedClass.name.text) == "ASCII" {
                return true
            }
        }
        if let nestedActor = member.decl.as(ActorDeclSyntax.self) {
            if Lint.Syntax.Identifier.unescaped(nestedActor.name.text) == "ASCII" {
                return true
            }
        }
        if let alias = member.decl.as(TypeAliasDeclSyntax.self) {
            if Lint.Syntax.Identifier.unescaped(alias.name.text) == "ASCII" {
                return true
            }
        }
    }
    return false
}
