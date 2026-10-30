internal import Lint
internal import SwiftSyntax

internal final class MemoryErrorNoncopyableVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    let extensionConformances: [Swift::String: Swift::Set<Swift::String>]
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        extensionConformances: [Swift::String: Swift::Set<Swift::String>]
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.extensionConformances = extensionConformances
        super.init(viewMode: .sourceAccurate)
    }

    private func conformsToError(
        name: TokenSyntax,
        inheritanceClause: InheritanceClauseSyntax?
    ) -> Bool {
        if let inheritanceClause {
            for inherited in inheritanceClause.inheritedTypes {
                var current = inherited.type
                while let attributed = current.as(AttributedTypeSyntax.self) {
                    current = attributed.baseType
                }
                if let identifier = current.as(IdentifierTypeSyntax.self),
                    identifier.name.text == "Error"
                {
                    return true
                }
                if let member = current.as(MemberTypeSyntax.self),
                    member.name.text == "Error",
                    let base = member.baseType.as(IdentifierTypeSyntax.self),
                    base.name.text == "Swift"
                {
                    return true
                }
            }
        }
        if extensionConformances[name.text]?.contains("Error") == true {
            return true
        }
        return false
    }

    private func suppressesCopyable(_ inheritanceClause: InheritanceClauseSyntax) -> Bool {
        for inherited in inheritanceClause.inheritedTypes {
            if let suppressed = inherited.type.as(SuppressedTypeSyntax.self) {
                let typeName = suppressed.type.trimmedDescription
                if typeName == "Copyable" || typeName.hasSuffix(".Copyable") {
                    return true
                }
            }
        }
        return false
    }

    private func check(name: TokenSyntax, inheritanceClause: InheritanceClauseSyntax?) {
        guard conformsToError(name: name, inheritanceClause: inheritanceClause) else { return }
        guard let inheritanceClause, suppressesCopyable(inheritanceClause) else { return }
        let location = converter.location(for: name.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "noncopyable error",
                message: memoryErrorNoncopyableMessage
            )
        )
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }
}
