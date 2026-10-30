public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `tagged extension public init` = Lint.Rule(
        id: "tagged extension public init",
        default: .warning,
        controls: [
            .init(
                id: "tagged extension public init exposed initializer",
                source: "extension Tagged { public init(rawValue: String) { fatalError() } }",
                path: "Sources/Raw Value Core/ExposedInitializer.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "tagged extension public init internal initializer",
                source: "extension Tagged { init(rawValue: String) { fatalError() } }",
                path: "Sources/Raw Value Core/InternalInitializer.swift",
                expectation: .clean
            ),
            .init(
                id: "tagged extension public init protocol witness boundary",
                source: "extension Tagged: Decodable { "
                    + "public init(from decoder: any Decoder) throws { fatalError() } }",
                path: "Sources/Raw Value Core/DecodableWitness.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            if Lint.Brand.owned(Lint.Brand.vocabulary, in: source) { return [] }
            let visitor = RawValueTaggedExtensionPublicInitVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let taggedExtensionPublicInitMessage: Swift::String =
    "[tagged extension public init] [PATTERN-019]: extensions on `Tagged` "
    + "MUST NOT provide `public init` — bypasses the brand's bounded invariants. "
    + "Callers reaching through an extension init never cross the validation gate "
    + "the tag owner controls. Drop the init, or move construction behind a "
    + "validating factory at the brand owner's layer."

private let taggedExtensionPublicInitProtocolWitnessCitations: [Swift::String: Swift::String] = [
    "ExpressibleByIntegerLiteral":
        "Swift.ExpressibleByIntegerLiteral — init(integerLiteral:) protocol witness",
    "ExpressibleByFloatLiteral":
        "Swift.ExpressibleByFloatLiteral — init(floatLiteral:) protocol witness",
    "ExpressibleByUnicodeScalarLiteral":
        "Swift.ExpressibleByUnicodeScalarLiteral — init(unicodeScalarLiteral:) protocol witness",
    "ExpressibleByExtendedGraphemeClusterLiteral":
        "Swift.ExpressibleByExtendedGraphemeClusterLiteral — init(extendedGraphemeClusterLiteral:) protocol witness",
    "ExpressibleByStringLiteral":
        "Swift.ExpressibleByStringLiteral — init(stringLiteral:) protocol witness",
    "ExpressibleByBooleanLiteral":
        "Swift.ExpressibleByBooleanLiteral — init(booleanLiteral:) protocol witness",
    "ExpressibleByStringInterpolation":
        "Swift.ExpressibleByStringInterpolation — init(stringInterpolation:) protocol witness",
    "ExpressibleByArrayLiteral":
        "Swift.ExpressibleByArrayLiteral — init(arrayLiteral:) protocol witness",
    "ExpressibleByDictionaryLiteral":
        "Swift.ExpressibleByDictionaryLiteral — init(dictionaryLiteral:) protocol witness",
    "ExpressibleByNilLiteral": "Swift.ExpressibleByNilLiteral — init(nilLiteral:) protocol witness",
    "LosslessStringConvertible": "Swift.LosslessStringConvertible — init?(_:) protocol witness",
    "RawRepresentable": "Swift.RawRepresentable — init?(rawValue:) protocol witness",
    "Decodable": "Swift.Decodable — init(from:) protocol witness",
    "Codable": "Swift.Codable — Decodable.init(from:) protocol witness",
    "Protocol":
        "Institute hoisted-protocol witness ([API-IMPL-009] pattern; e.g., Carrier.Protocol)",
    "`Protocol`":
        "Institute hoisted-protocol witness ([API-IMPL-009] pattern; e.g., Carrier.`Protocol`)",
]

internal final class RawValueTaggedExtensionPublicInitVisitor: SyntaxVisitor {
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

    private func extendsTagged(_ extendedType: TypeSyntax) -> Bool {
        if let identifier = extendedType.as(IdentifierTypeSyntax.self) {
            return Lint.Syntax.Identifier.unescaped(identifier.name.text) == "Tagged"
        }
        if let member = extendedType.as(MemberTypeSyntax.self) {
            return Lint.Syntax.Identifier.unescaped(member.name.text) == "Tagged"
        }
        return false
    }

    private func hasPublicModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            if modifier.name.tokenKind == .keyword(.public)
                || modifier.name.tokenKind == .keyword(.open)
            {
                return true
            }
        }
        return false
    }

    private func hasExplicitNonPublicAccessModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.private), .keyword(.fileprivate), .keyword(.internal):
                return true

            default:
                continue
            }
        }
        return false
    }

    private func isEffectivelyPublicInit(
        initModifiers: DeclModifierListSyntax,
        extensionModifiers: DeclModifierListSyntax
    ) -> Bool {
        if hasPublicModifier(initModifiers) {
            return true
        }
        if hasExplicitNonPublicAccessModifier(initModifiers) {
            return false
        }
        return hasPublicModifier(extensionModifiers)
    }

    private func inheritanceLeafNames(_ clause: InheritanceClauseSyntax?) -> [Swift::String] {
        guard let clause else { return [] }
        var names: [Swift::String] = []
        for inherited in clause.inheritedTypes {
            if let identifier = inherited.type.as(IdentifierTypeSyntax.self) {
                names.append(identifier.name.text)
            } else if let member = inherited.type.as(MemberTypeSyntax.self) {
                names.append(member.name.text)
            }
        }
        return names
    }

    private func isFreeGenericTagDomainExtension(_ clause: GenericWhereClauseSyntax?) -> Swift::Bool {
        guard let clause else { return false }
        var bindsUnderlying = false
        var bindsTag = false
        for requirement in clause.requirements {
            guard let sameType = requirement.requirement.as(SameTypeRequirementSyntax.self) else {
                continue
            }
            let lhs = sameType.leftType.trimmedDescription
            if lhs == "Underlying" {
                bindsUnderlying = true
            } else if lhs == "Tag" {
                bindsTag = true
            }
        }
        return bindsUnderlying && !bindsTag
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard extendsTagged(node.extendedType) else {
            return .visitChildren
        }
        let conformingProtocols = inheritanceLeafNames(node.inheritanceClause)
        let isProtocolWitnessExtension = conformingProtocols.contains { proto in
            taggedExtensionPublicInitProtocolWitnessCitations[proto] != nil
        }
        if isProtocolWitnessExtension {
            return .visitChildren
        }
        if isFreeGenericTagDomainExtension(node.genericWhereClause) {
            return .visitChildren
        }
        for member in node.memberBlock.members {
            guard let initDecl = member.decl.as(InitializerDeclSyntax.self) else {
                continue
            }
            guard
                isEffectivelyPublicInit(
                    initModifiers: initDecl.modifiers,
                    extensionModifiers: node.modifiers
                )
            else {
                continue
            }
            let location = converter.location(
                for: initDecl.initKeyword.positionAfterSkippingLeadingTrivia
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
                    identifier: "tagged extension public init",
                    message: taggedExtensionPublicInitMessage
                )
            )
        }
        return .visitChildren
    }
}
