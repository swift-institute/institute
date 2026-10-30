public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `literal conformance shadows validating init` = Lint.Rule(
        id: "literal conformance shadows validating init",
        default: .warning,
        controls: [
            .init(
                id: "literal conformance shadows validating init violation",
                source: "struct Value: ExpressibleByStringLiteral { init(_ value: some StringProtocol) throws {} }",
                path: "Sources/Idiom Core/Value.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "literal conformance shadows validating init lawful",
                source: "struct Value { init(_ value: some StringProtocol) throws {} }",
                path: "Sources/Idiom Core/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "literal conformance shadows validating init near miss",
                source: "struct Value {}\nextension Value: Swift.ExpressibleByStringLiteral {}\nextension Value { init(_ value: some Swift.StringProtocol) throws(Value.Error) {} }",
                path: "Sources/Idiom Core/Value.swift",
                expectation: .findings(1)
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = IdiomLiteralConformanceShadowsValidatingInitVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.resolvedMatches()
        }
    )
}

@usableFromInline
internal let idiomLiteralConformanceShadowsValidatingInitMessage: Swift::String =
    "[literal conformance shadows validating init]: a type conforming to "
    + "`ExpressibleByStringLiteral` also declares a throwing "
    + "`init(_: some StringProtocol)`, so string-literal construction bypasses "
    + "that validating initializer. Remove the literal conformance."

internal final class IdiomLiteralConformanceShadowsValidatingInitVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter

    private var enclosingPath: [Swift::String] = []
    private var extensionPushCounts: [Swift::Int] = []
    private var conformancePositions: [Swift::String: AbsolutePosition] = [:]
    private var validatingInitializerPaths: Swift::Set<Swift::String> = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    private var currentPath: Swift::String { enclosingPath.joined(separator: ".") }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        enterType(named: node.name, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }

    override func visitPost(_: StructDeclSyntax) { _ = enclosingPath.popLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        enterType(named: node.name, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }

    override func visitPost(_: ClassDeclSyntax) { _ = enclosingPath.popLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        enterType(named: node.name, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }

    override func visitPost(_: EnumDeclSyntax) { _ = enclosingPath.popLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        enterType(named: node.name, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }

    override func visitPost(_: ActorDeclSyntax) { _ = enclosingPath.popLast() }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let components = qualifiedPathComponents(node.extendedType) ?? ["<unknown>"]
        enclosingPath.append(contentsOf: components)
        extensionPushCounts.append(components.count)
        recordConformance(node.inheritanceClause)
        return .visitChildren
    }

    override func visitPost(_: ExtensionDeclSyntax) {
        let count = extensionPushCounts.removeLast()
        enclosingPath.removeLast(count)
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard isThrowingStringProtocolInitializer(node) else { return .visitChildren }
        validatingInitializerPaths.insert(currentPath)
        return .visitChildren
    }

    internal func resolvedMatches() -> [Diagnostic.Record] {
        conformancePositions.keys.sorted().compactMap { path in
            guard validatingInitializerPaths.contains(path),
                let position = conformancePositions[path]
            else { return nil }
            let location = converter.location(for: position)
            return Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "literal conformance shadows validating init",
                message: idiomLiteralConformanceShadowsValidatingInitMessage
            )
        }
    }

    private func enterType(named name: TokenSyntax, inheritanceClause: InheritanceClauseSyntax?) {
        enclosingPath.append(Lint.Syntax.Identifier.unescaped(name.text))
        recordConformance(inheritanceClause)
    }

    private func recordConformance(_ clause: InheritanceClauseSyntax?) {
        guard let clause else { return }
        for inherited in clause.inheritedTypes
        where isNamed(inherited.type, "ExpressibleByStringLiteral") {
            conformancePositions[currentPath] = inherited.type.positionAfterSkippingLeadingTrivia
        }
    }

    private func isThrowingStringProtocolInitializer(
        _ node: InitializerDeclSyntax
    ) -> Swift::Bool {
        guard node.signature.effectSpecifiers?.throwsClause != nil,
            node.signature.parameterClause.parameters.count == 1,
            let parameter = node.signature.parameterClause.parameters.first,
            parameter.firstName.tokenKind == .wildcard,
            let opaque = parameter.type.as(SomeOrAnyTypeSyntax.self),
            opaque.someOrAnySpecifier.tokenKind == .keyword(.some)
        else { return false }
        return isNamed(opaque.constraint, "StringProtocol")
    }

    private func qualifiedPathComponents(_ type: TypeSyntax) -> [Swift::String]? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return [Lint.Syntax.Identifier.unescaped(identifier.name.text)]
        }
        if let member = type.as(MemberTypeSyntax.self) {
            guard var base = qualifiedPathComponents(member.baseType) else { return nil }
            base.append(Lint.Syntax.Identifier.unescaped(member.name.text))
            return base
        }
        return nil
    }

    private func isNamed(_ type: TypeSyntax, _ name: Swift::String) -> Swift::Bool {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return Lint.Syntax.Identifier.unescaped(identifier.name.text) == name
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return Lint.Syntax.Identifier.unescaped(member.name.text) == name
        }
        return false
    }
}
