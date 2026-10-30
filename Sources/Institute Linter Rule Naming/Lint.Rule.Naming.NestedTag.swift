public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `nested tag` = Lint.Rule(
        id: "nested tag",
        default: .warning,
        controls: [
            .init(
                id: "nested tag empty nested",
                source: "enum Order { enum Tag {} }",
                path: "Sources/Naming Core/EmptyNestedTag.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "nested tag top level",
                source: "enum Tag {}",
                path: "Sources/Naming Core/TopLevelTag.swift",
                expectation: .clean
            ),
            .init(
                id: "nested tag witness key in same file",
                source: "extension Test.Trait { public struct Tag: Sendable {} }\nextension Test.Trait.Tag: Witness.Key { public static var liveValue: Int { 0 } }",
                path: "Sources/Naming Core/WitnessTag.swift",
                expectation: .clean
            ),
            .init(
                id: "nested tag with members only",
                source: "enum Order { enum Tag { static let name = \"order\" } }",
                path: "Sources/Naming Core/MemberTag.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "nested tag marker conformances only",
                source: "enum Order { enum Tag: Sendable, Hashable {} }\nextension Order.Tag: Equatable {}",
                path: "Sources/Naming Core/MarkerTag.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "nested tag behaviour on another type",
                source: "enum Order { enum Tag {} }\nextension Order: Witness.Key { static var liveValue: Int { 0 } }",
                path: "Sources/Naming Core/OtherBehaviour.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "nested tag data bearing",
                source: "enum Order { struct Tag { let value: Int } }",
                path: "Sources/Naming Core/DataBearingTag.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let extensions = NamingNestedTagConformanceCollector(viewMode: .sourceAccurate)
            extensions.walk(source.tree)
            let visitor = NamingNestedTagVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter,
                typesWithConformance: extensions.typesWithConformance
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let namingNestedTagMessage: Swift::String =
    "[nested tag] [API-NAME-010a]: empty `Tag` sub-type nested inside another type "
    + "— the surrounding namespace MUST play the phantom role directly. "
    + "Use `Property<Order, T>` / `Tagged<Order, T>` instead of "
    + "`Property<Order.Tag, T>` / `Tagged<Order.Tag, T>`."

internal final class NamingNestedTagVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    let typesWithConformance: Swift::Set<Swift::String>
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        typesWithConformance: Swift::Set<Swift::String>
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.typesWithConformance = typesWithConformance
        super.init(viewMode: .sourceAccurate)
    }

    private func conformsBeyondMarkers(
        _ node: some DeclGroupSyntax,
        name: Swift::String
    ) -> Swift::Bool {
        nestedTagConformsBeyondMarkers(inheritance: node.inheritanceClause)
            || nestedTagQualifiedName(of: Syntax(node), name: name).map(typesWithConformance.contains) ?? false
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.name.text == "Tag" else { return .visitChildren }
        guard !namingHasStoredInstanceProperty(node.memberBlock) else { return .visitChildren }
        guard nestedTagIsNested(Syntax(node)) else { return .visitChildren }
        guard !conformsBeyondMarkers(node, name: node.name.text) else { return .visitChildren }
        emit(at: node.name.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.name.text == "Tag" else { return .visitChildren }
        guard !namingHasEnumCase(node.memberBlock) else { return .visitChildren }
        guard nestedTagIsNested(Syntax(node)) else { return .visitChildren }
        guard !conformsBeyondMarkers(node, name: node.name.text) else { return .visitChildren }
        emit(at: node.name.positionAfterSkippingLeadingTrivia)
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
                identifier: "nested tag",
                message: namingNestedTagMessage
            )
        )
    }
}

private func nestedTagIsNested(_ node: Syntax) -> Swift::Bool {
    var current: Syntax? = node.parent
    while let candidate = current {
        if candidate.is(StructDeclSyntax.self) { return true }
        if candidate.is(ClassDeclSyntax.self) { return true }
        if candidate.is(EnumDeclSyntax.self) { return true }
        if candidate.is(ActorDeclSyntax.self) { return true }
        if candidate.is(ExtensionDeclSyntax.self) { return true }
        current = candidate.parent
    }
    return false
}

private let nestedTagMarkerProtocols: Swift::Set<Swift::String> = [
    "Sendable", "Hashable", "Equatable", "Copyable", "Escapable", "BitwiseCopyable",
]

private func nestedTagConformsBeyondMarkers(inheritance: InheritanceClauseSyntax?) -> Swift::Bool {
    inheritance?.inheritedTypes.contains { inherited in
        inherited.type.is(SuppressedTypeSyntax.self) == false
            && !nestedTagMarkerProtocols.contains(
                inherited.type.trimmedDescription.split(separator: ".").last.map(Swift::String.init) ?? ""
            )
    } ?? false
}

private func nestedTagQualifiedName(of node: Syntax, name: Swift::String) -> Swift::String? {
    var components: [Swift::String] = [name]
    var current: Syntax? = node.parent
    while let candidate = current {
        if let decl = candidate.as(StructDeclSyntax.self) {
            components.insert(decl.name.text, at: 0)
        } else if let decl = candidate.as(EnumDeclSyntax.self) {
            components.insert(decl.name.text, at: 0)
        } else if let decl = candidate.as(ClassDeclSyntax.self) {
            components.insert(decl.name.text, at: 0)
        } else if let decl = candidate.as(ActorDeclSyntax.self) {
            components.insert(decl.name.text, at: 0)
        } else if let decl = candidate.as(ExtensionDeclSyntax.self) {
            components.insert(decl.extendedType.trimmedDescription, at: 0)
            return components.joined(separator: ".")
        }
        current = candidate.parent
    }
    return components.joined(separator: ".")
}

internal final class NamingNestedTagConformanceCollector: SyntaxVisitor {
    var typesWithConformance: Swift::Set<Swift::String> = []

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        if nestedTagConformsBeyondMarkers(inheritance: node.inheritanceClause) {
            typesWithConformance.insert(node.extendedType.trimmedDescription)
        }
        return .visitChildren
    }
}
