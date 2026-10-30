public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `associated type shadows namespace` = Lint.Rule(
        id: "associated type shadows namespace",
        default: .warning,
        controls: [
            .init(
                id: "associated type shadows namespace violation",
                source: "extension Coder { protocol Codable { associatedtype Coder } }",
                path: "Sources/Naming Core/Coder.Codable.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "associated type shadows namespace top level alias",
                source: "public typealias Coding = Coder.Protocol",
                path: "Sources/Naming Core/Coding.swift",
                expectation: .clean
            ),
            .init(
                id: "associated type shadows namespace nested type near miss",
                source: "extension Coder.Codable { struct Coder {} }",
                path: "Sources/Naming Core/Coder.Codable.Coder.swift",
                expectation: .findings(1)
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = NamingAssociatedTypeShadowsNamespaceVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let namingAssociatedTypeShadowsNamespaceMessage: Swift::String =
    "[associated type shadows namespace]: an associated type or nested type declared "
    + "directly in a protocol or extension has the same name as its enclosing namespace "
    + "root; use a top-level protocol typealias at conformance sites so the nested name "
    + "does not shadow the namespace."

internal final class NamingAssociatedTypeShadowsNamespaceVisitor: SyntaxVisitor {
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

    override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.name, declaration: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.name, declaration: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.name, declaration: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.name, declaration: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.name, declaration: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.name, declaration: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.name, declaration: Syntax(node))
        return .visitChildren
    }

    private func check(_ name: TokenSyntax, declaration: Syntax) {
        guard let namespace = enclosingNamespaceRoot(for: declaration) else { return }
        guard Lint.Syntax.Identifier.unescaped(name.text) == namespace else { return }
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
                identifier: "associated type shadows namespace",
                message: namingAssociatedTypeShadowsNamespaceMessage
            )
        )
    }
}

private func enclosingNamespaceRoot(for declaration: Syntax) -> Swift::String? {
    var current = declaration.parent
    while let candidate = current {
        if let protocolDecl = candidate.as(ProtocolDeclSyntax.self) {
            return namespaceRoot(enclosing: Syntax(protocolDecl))
        }
        if let extensionDecl = candidate.as(ExtensionDeclSyntax.self) {
            return namespaceRoot(of: extensionDecl.extendedType)
        }
        if candidate.is(StructDeclSyntax.self) || candidate.is(ClassDeclSyntax.self)
            || candidate.is(EnumDeclSyntax.self) || candidate.is(ActorDeclSyntax.self)
            || candidate.is(TypeAliasDeclSyntax.self)
        {
            return nil
        }
        current = candidate.parent
    }
    return nil
}

private func namespaceRoot(enclosing declaration: Syntax) -> Swift::String? {
    var current = declaration.parent
    while let candidate = current {
        if let enumDecl = candidate.as(EnumDeclSyntax.self) {
            return Lint.Syntax.Identifier.unescaped(enumDecl.name.text)
        }
        if let extensionDecl = candidate.as(ExtensionDeclSyntax.self) {
            return namespaceRoot(of: extensionDecl.extendedType)
        }
        if candidate.is(StructDeclSyntax.self) || candidate.is(ClassDeclSyntax.self)
            || candidate.is(ActorDeclSyntax.self) || candidate.is(ProtocolDeclSyntax.self)
        {
            return nil
        }
        current = candidate.parent
    }
    return nil
}

private func namespaceRoot(of type: TypeSyntax) -> Swift::String? {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return Lint.Syntax.Identifier.unescaped(identifier.name.text)
    }
    if let member = type.as(MemberTypeSyntax.self) {
        return namespaceRoot(of: member.baseType)
    }
    if let attributed = type.as(AttributedTypeSyntax.self) {
        return namespaceRoot(of: attributed.baseType)
    }
    return nil
}
