public import Lint
internal import SwiftSyntax

extension Lint.Rule {

    public static let `frozen tower type` = Lint.Rule(
        id: "frozen tower type",
        default: .warning,
        controls: [
            .init(
                id: "frozen tower type stdlib extension with module selector",
                source: "extension Swift::Array { public struct Serializer { public let elements: [Element] } }",
                path: "Controls/FrozenTowerType.swift",
                expectation: .clean
            ),
            .init(
                id: "frozen tower type stdlib extension with member path",
                source: "extension Swift.Array { public struct Serializer { public let elements: [Element] } }",
                path: "Controls/FrozenTowerType.swift",
                expectation: .clean
            ),
            .init(
                id: "frozen tower type missing attribute",
                source: """
                    extension Storage {
                        public struct Generational {
                            public var count: Int
                        }
                    }
                    """,
                path: "Controls/FrozenTowerType.swift",
                expectation: .findings(1)
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = FrozenTowerTypeVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let frozenTowerTypeMessage: Swift::String =
    "[frozen tower type] [API-IMPL-022]: public stored value types in the storage tower "
    + "are @frozen (layout-locked from birth) so cross-module consuming decomposition "
    + "(take()-style unwraps, consuming makeIterator()) stays legal without "
    + "defining-module workarounds. Add @frozen to the declaration. Views/iterators/"
    + "snapshots are exempt until cross-module partial consumption is demonstrated "
    + "(the ruled exemption); if this type is one, name it per the exemption class or "
    + "exclude per the rule-exemptions shapes."

internal final class FrozenTowerTypeVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    private static let towerRoots: Swift::Set<Swift::String> = [
        "Storage", "Store", "Buffer", "Shared", "Array", "Fixed", "Column",
        "Queue", "Deque", "SlotMap", "Stack", "Heap", "Tree", "Graph", "Hash",
        "Set", "Dictionary",
    ]

    private static let exemptNames: Swift::Set<Swift::String> = [
        "Checkpoint", "Scalar", "Segments", "Walk", "Iterator", "View",
    ]

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard isPublic(node.modifiers) else { return .visitChildren }
        guard !hasFrozen(node.attributes) else { return .visitChildren }
        let name = node.name.text
        guard !Self.exemptNames.contains(name),
            !name.hasSuffix("Iterator"),
            !name.hasSuffix("View")
        else { return .visitChildren }
        guard !suppressesEscapable(node.inheritanceClause) else { return .visitChildren }
        guard hasStoredProperty(node.memberBlock) else { return .visitChildren }
        guard let root = rootNamespace(of: node), Self.towerRoots.contains(root) else {
            return .visitChildren
        }

        let token = node.name
        let location = converter.location(for: token.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "frozen tower type",
                message: frozenTowerTypeMessage
            )
        )
        return .visitChildren
    }

    private func isPublic(_ modifiers: DeclModifierListSyntax) -> Swift::Bool {
        modifiers.contains { $0.name.text == "public" }
    }

    private func hasFrozen(_ attributes: AttributeListSyntax) -> Swift::Bool {
        attributes.contains { element in
            guard case .attribute(let attribute) = element else { return false }
            return attribute.attributeName.trimmedDescription == "frozen"
        }
    }

    private func suppressesEscapable(_ clause: InheritanceClauseSyntax?) -> Swift::Bool {
        guard let clause else { return false }
        return clause.inheritedTypes.contains { inherited in
            guard let suppressed = inherited.type.as(SuppressedTypeSyntax.self) else {
                return false
            }
            return suppressed.type.trimmedDescription == "Escapable"
        }
    }

    private func hasStoredProperty(_ memberBlock: MemberBlockSyntax) -> Swift::Bool {
        memberBlock.members.contains { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { return false }
            guard !variable.modifiers.contains(where: { $0.name.text == "static" }) else {
                return false
            }
            return variable.bindings.contains { $0.accessorBlock == nil }
        }
    }

    private func rootNamespace(of node: StructDeclSyntax) -> Swift::String? {
        var outermost: Swift::String? = node.name.text
        var current: Syntax? = node.parent
        while let ancestor = current {
            if let ext = ancestor.as(ExtensionDeclSyntax.self) {
                outermost = baseIdentifier(of: ext.extendedType)
            } else if let nominal = ancestor.asProtocol((any NamedDeclSyntax).self),
                ancestor.is(StructDeclSyntax.self) || ancestor.is(EnumDeclSyntax.self)
                    || ancestor.is(ClassDeclSyntax.self) || ancestor.is(ActorDeclSyntax.self)
            {
                outermost = nominal.name.text
            }
            current = ancestor.parent
        }
        return outermost
    }

    private func baseIdentifier(of type: TypeSyntax) -> Swift::String? {
        if let member = type.as(MemberTypeSyntax.self) {
            return baseIdentifier(of: member.baseType)
        }
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.moduleSelector?.moduleName.text == "Swift" ? "Swift" : identifier.name.text
        }
        return nil
    }
}
