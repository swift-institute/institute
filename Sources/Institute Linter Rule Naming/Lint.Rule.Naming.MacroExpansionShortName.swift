public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `macro expansion short name` = Lint.Rule(
        id: "macro expansion short name",
        default: .warning,
        controls: [
            .init(
                id: "macro expansion short name unqualified extension target",
                source: """
                    struct ValueMacro: ExtensionMacro {
                        static func expansion() -> [ExtensionDeclSyntax] {
                            ["extension Value: Swift.Sendable {}"]
                        }
                    }
                    """,
                path: "Sources/Value Macros/ValueMacro.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "macro expansion short name fully qualified types",
                source: """
                    struct ValueMacro: ExtensionMacro {
                        static func expansion() -> [ExtensionDeclSyntax] {
                            ["extension Domain.Value: Swift.Sendable {}"]
                        }
                    }
                    """,
                path: "Sources/Value Macros/ValueMacro.swift",
                expectation: .clean
            ),
            .init(
                id: "macro expansion short name unqualified inherited type",
                source: """
                    struct ValueMacro: ExtensionMacro {
                        static func expansion() -> [ExtensionDeclSyntax] {
                            ["extension Domain.Value: Sendable {}"]
                        }
                    }
                    """,
                path: "Sources/Value Macros/ValueMacro.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "macro expansion short name non macro code",
                source: """
                    struct Builder {
                        static func expansion() -> Swift.String {
                            "extension Value: Swift.Sendable {}"
                        }
                    }
                    """,
                path: "Sources/Builder/Builder.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = NamingMacroExpansionShortNameVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

internal func namingMacroExpansionShortNameMessage(_ name: Swift::String) -> Swift::String {
    "[macro expansion short name]: macro-generated source refers to the type `\(name)` by a "
        + "short or unqualified name; spell the full type name."
}

internal final class NamingMacroExpansionShortNameVisitor: SyntaxVisitor {
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

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.name.text == "expansion",
            node.modifiers.contains(where: {
                $0.name.text == "static" || $0.name.text == "class"
            }),
            namingMacroExpansionShortNameIsMacroImplementation(node),
            let body = node.body
        else { return .visitChildren }

        let finder = NamingMacroExpansionShortNameFinder(viewMode: .sourceAccurate)
        finder.walk(body)
        for finding in finder.matches {
            let location = converter.location(
                for: finding.literal.openingQuote.positionAfterSkippingLeadingTrivia
            )
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "macro expansion short name",
                    message: namingMacroExpansionShortNameMessage(finding.name)
                )
            )
        }
        return .skipChildren
    }
}

private let namingMacroExpansionShortNameProtocols: Swift::Set<Swift::String> = [
    "AccessorMacro",
    "BodyMacro",
    "CodeItemMacro",
    "DeclarationMacro",
    "ExpressionMacro",
    "ExtensionMacro",
    "MemberAttributeMacro",
    "MemberMacro",
    "PeerMacro",
    "PreambleMacro",
]

private func namingMacroExpansionShortNameIsMacroImplementation(
    _ node: FunctionDeclSyntax
) -> Swift::Bool {
    var current = Syntax(node).parent
    while let candidate = current {
        if let declaration = candidate.as(StructDeclSyntax.self) {
            return namingMacroExpansionShortNameHasMacroConformance(declaration.inheritanceClause)
        }
        if let declaration = candidate.as(EnumDeclSyntax.self) {
            return namingMacroExpansionShortNameHasMacroConformance(declaration.inheritanceClause)
        }
        if let declaration = candidate.as(ClassDeclSyntax.self) {
            return namingMacroExpansionShortNameHasMacroConformance(declaration.inheritanceClause)
        }
        if let declaration = candidate.as(ActorDeclSyntax.self) {
            return namingMacroExpansionShortNameHasMacroConformance(declaration.inheritanceClause)
        }
        if let declaration = candidate.as(ExtensionDeclSyntax.self) {
            return namingMacroExpansionShortNameHasMacroConformance(declaration.inheritanceClause)
        }
        current = candidate.parent
    }
    return false
}

private func namingMacroExpansionShortNameHasMacroConformance(
    _ clause: InheritanceClauseSyntax?
) -> Swift::Bool {
    guard let clause else { return false }
    for inherited in clause.inheritedTypes {
        if let identifier = inherited.type.as(IdentifierTypeSyntax.self),
            namingMacroExpansionShortNameProtocols.contains(identifier.name.text)
        {
            return true
        }
        if let member = inherited.type.as(MemberTypeSyntax.self),
            namingMacroExpansionShortNameProtocols.contains(member.name.text)
        {
            return true
        }
    }
    return false
}
