public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `namespace adoption typealias` = Lint.Rule(
        id: "namespace adoption typealias",
        default: .note,
        controls: [
            .init(
                id: "namespace adoption typealias module selector",
                source: "public typealias Span = Swift::Span",
                path: "Sources/Naming Core/Span.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "namespace adoption typealias same leaf",
                source: "public typealias Event = Kernel.Event",
                path: "Sources/Naming Core/SameLeaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "namespace adoption typealias different leaf",
                source: "public typealias SourceLocation = Text.Location",
                path: "Sources/Naming Core/DifferentLeaf.swift",
                expectation: .clean
            ),
            .init(
                id: "namespace adoption typealias conforming context",
                source: "extension Tagged: Collection { public typealias Index = Underlying.Index }",
                path: "Sources/Naming Core/ConformingContext.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = NamingNamespaceAdoptionVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let namingNamespaceAdoptionMessage: Swift::String =
    "[namespace adoption typealias] [API-NAME-004a]: same-leaf typealias is "
    + "the namespace-adoption shape. Confirm the higher-layer namespace "
    + "declares ≥ 5 sibling types / extensions / methods on the adopted "
    + "concept — otherwise this is a rename bridge per [API-NAME-004]. "
    + "Surfaced as a non-counting review prompt. (The parameterized-adoption idiom — a "
    + "generic typealias forwarding its parameter(s) while binding the "
    + "enclosing Self-type into the underlying generic — does not fire.)"

private func namingQualifiedAliasTarget(
    _ type: TypeSyntax
) -> (leaf: Swift::String, arguments: GenericArgumentClauseSyntax?)? {
    if let member = type.as(MemberTypeSyntax.self) {
        return (member.name.text, member.genericArgumentClause)
    }
    if let identifier = type.as(IdentifierTypeSyntax.self), identifier.moduleSelector != nil {
        return (identifier.name.text, identifier.genericArgumentClause)
    }
    return nil
}

private func namingIsParameterizedAdoption(
    _ node: TypeAliasDeclSyntax,
    arguments: GenericArgumentClauseSyntax?
) -> Swift::Bool {
    guard let lhsParameters = node.genericParameterClause?.parameters,
        !lhsParameters.isEmpty
    else { return false }
    guard let rhsArguments = arguments?.arguments,
        !rhsArguments.isEmpty
    else { return false }

    var lhsParameterNames: Swift::Set<Swift::String> = []
    for parameter in lhsParameters { lhsParameterNames.insert(parameter.name.text) }

    var forwardsAParameter = false
    var bindsAnExtraArgument = false
    for argument in rhsArguments {
        if let identifier = argument.argument.as(IdentifierTypeSyntax.self),
            identifier.genericArgumentClause == nil,
            lhsParameterNames.contains(identifier.name.text)
        {
            forwardsAParameter = true
        } else {
            bindsAnExtraArgument = true
        }
    }
    return forwardsAParameter && bindsAnExtraArgument
}

internal final class NamingNamespaceAdoptionVisitor: SyntaxVisitor {
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

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        let lhsName = node.name.text
        guard let target = namingQualifiedAliasTarget(node.initializer.value) else {
            return .visitChildren
        }
        guard target.leaf == lhsName else { return .visitChildren }
        if Naming.isInsideConformingContext(Syntax(node)) {
            return .visitChildren
        }
        if namingIsParameterizedAdoption(node, arguments: target.arguments) {
            return .visitChildren
        }
        let location = converter.location(
            for: node.typealiasKeyword.positionAfterSkippingLeadingTrivia
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
                identifier: "namespace adoption typealias",
                message: namingNamespaceAdoptionMessage
            )
        )
        return .visitChildren
    }
}
