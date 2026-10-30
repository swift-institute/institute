public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `existential parameter` = Lint.Rule(
        id: "existential parameter",
        default: .warning,
        controls: [
            .init(
                id: "existential parameter any protocol",
                source: "func render(_ view: any View) {}",
                path: "Sources/Idiom Consumer/Render.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "existential parameter generic",
                source: "func render(_ view: some View) {}",
                path: "Sources/Idiom Consumer/Render.swift",
                expectation: .clean
            ),
            .init(
                id: "existential parameter any error",
                source: "func report(_ error: any Error) {}",
                path: "Sources/Idiom Consumer/Report.swift",
                expectation: .clean
            ),
            .init(
                id: "existential parameter encodable witness",
                source: "extension Box: Encodable { func encode(to encoder: any Encoder) throws {} }",
                path: "Sources/Idiom Consumer/Box.swift",
                expectation: .clean
            ),
            .init(
                id: "existential parameter decodable witness",
                source: "extension Box: Decodable { init(from decoder: any Decoder) throws {} }",
                path: "Sources/Idiom Consumer/Box.swift",
                expectation: .clean
            ),
            .init(
                id: "existential parameter encoder outside witness",
                source: "func log(_ encoder: any Encoder) {}",
                path: "Sources/Idiom Consumer/Log.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "existential parameter test",
                source: "func render(_ view: any View) {}",
                path: "Tests/Idiom Consumer Tests/Render.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let path = source.file.filePath
            guard path.hasPrefix("Sources/") || path.contains("/Sources/") else {
                return []
            }
            let visitor = IdiomExistentialParameterVisitor(
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
internal let idiomExistentialParameterMessage: Swift::String =
    "[existential parameter] [SOURCE-EXISTENTIAL-PARAMETER]: a parameter typed "
    + "`any P` boxes its argument and erases its type; take `some P` or a "
    + "generic parameter instead. `any Error` is admitted."

internal let idiomExistentialParameterNestedMessage: Swift::String =
    "[existential parameter] [SOURCE-EXISTENTIAL-PARAMETER]: `any P` inside a "
    + "parameter's type (for example `[any P]`) boxes each element. If the elements "
    + "share one concrete type, take `[some P]` or a generic `[T]`. If they must "
    + "differ, `some P` cannot express that: take a parameter pack "
    + "(`repeat each T` with `T: P`) or an enum of the concrete cases. "
    + "`any Error` is admitted."

internal final class IdiomExistentialParameterVisitor: SyntaxVisitor {
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

    override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        guard !IdiomExistentialParameterCodableWitness.matches(node) else {
            return .visitChildren
        }
        let finder = IdiomExistentialParameterFinder(viewMode: .sourceAccurate)
        finder.walk(node.type)
        let topLevel = idiomExistentialParameterUnwrapped(node.type).is(SomeOrAnyTypeSyntax.self)
        for position in finder.positions {
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
                    identifier: "existential parameter",
                    message: topLevel ? idiomExistentialParameterMessage : idiomExistentialParameterNestedMessage
                )
            )
        }
        return .visitChildren
    }
}

internal func idiomExistentialParameterUnwrapped(_ type: TypeSyntax) -> TypeSyntax {
    if let attributed = type.as(AttributedTypeSyntax.self) {
        return idiomExistentialParameterUnwrapped(attributed.baseType)
    }
    if let optional = type.as(OptionalTypeSyntax.self) {
        return idiomExistentialParameterUnwrapped(optional.wrappedType)
    }
    if let tuple = type.as(TupleTypeSyntax.self), tuple.elements.count == 1, let only = tuple.elements.first {
        return idiomExistentialParameterUnwrapped(only.type)
    }
    return type
}

internal enum IdiomExistentialParameterCodableWitness {
    static func matches(_ parameter: FunctionParameterSyntax) -> Bool {
        guard let list = parameter.parent?.as(FunctionParameterListSyntax.self), list.count == 1,
            let signature = list.parent?.parent?.as(FunctionSignatureSyntax.self),
            let type = parameter.type.as(SomeOrAnyTypeSyntax.self),
            type.someOrAnySpecifier.tokenKind == .keyword(.any)
        else {
            return false
        }
        let label = parameter.firstName.text
        let constraint = type.constraint.trimmedDescription
        return switch signature.parent {
        case let function? where function.as(FunctionDeclSyntax.self)?.name.text == "encode":
            label == "to" && ["Encoder", "Swift.Encoder", "Swift::Encoder"].contains(constraint)
                && Self.conforms(function, to: "Encodable")
        case let initializer? where initializer.is(InitializerDeclSyntax.self):
            label == "from" && ["Decoder", "Swift.Decoder", "Swift::Decoder"].contains(constraint)
                && Self.conforms(initializer, to: "Decodable")
        default:
            false
        }
    }

    static func conforms(_ member: Syntax, to requirement: Swift::String) -> Bool {
        let accepted: Set<Swift::String> = [
            requirement, "Swift.\(requirement)", "Swift::\(requirement)",
            "Codable", "Swift.Codable", "Swift::Codable",
        ]
        guard
            let group = sequence(first: member, next: \.parent)
                .dropFirst()
                .lazy
                .compactMap({ $0.asProtocol((any DeclGroupSyntax).self) })
                .first
        else {
            return false
        }
        return group.inheritanceClause?.inheritedTypes.contains {
            accepted.contains($0.type.trimmedDescription)
        } ?? false
    }
}

internal final class IdiomExistentialParameterFinder: SyntaxVisitor {
    var positions: [AbsolutePosition] = []

    override func visit(_ node: SomeOrAnyTypeSyntax) -> SyntaxVisitorContinueKind {
        let constraint = node.constraint.trimmedDescription
        if node.someOrAnySpecifier.tokenKind == .keyword(.any),
            constraint != "Error", constraint != "Swift.Error", constraint != "Swift::Error"
        {
            positions.append(node.positionAfterSkippingLeadingTrivia)
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionTypeSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }
}
