public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `existential throws` = Lint.Rule(
        id: "existential throws",
        default: .warning,
        controls: [
            .init(
                id: "existential throws any error",
                source: "func read() throws(any Error) {}",
                path: "Sources/Throws Consumer/ExistentialError.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "existential throws concrete error",
                source: "func read() throws(Read.Error) {}",
                path: "Sources/Throws Consumer/ConcreteError.swift",
                expectation: .clean
            ),
            .init(
                id: "existential throws encodable witness",
                source: "extension Value: Encodable { "
                    + "func encode(to encoder: any Encoder) throws(any Error) {} }",
                path: "Sources/Throws Consumer/EncodableWitness.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ThrowsExistentialVisitor(
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
internal let throwsExistentialMessage: Swift::String =
    "[existential throws] feedback_no_existential_throws: `throws(any Error)` boxes "
    + "the error as an existential — semantically identical to untyped `throws`. "
    + "Use a concrete error type or make the container generic over the error type."

@usableFromInline
internal let throwsExistentialStdlibProtocolWitnessCitations: [Swift::String: (witness: Swift::String, protocols: [Swift::String])] = [
    "init(from:)": (
        witness: "Swift.Decodable.init(from:) throws — protocol requirement is untyped",
        protocols: ["Decodable", "Codable"]
    ),
    "encode(to:)": (
        witness: "Swift.Encodable.encode(to:) throws — protocol requirement is untyped",
        protocols: ["Encodable", "Codable"]
    ),
]

internal final class ThrowsExistentialVisitor: SyntaxVisitor {
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

    override func visit(_ node: ThrowsClauseSyntax) -> SyntaxVisitorContinueKind {
        guard let typed = node.type else { return .visitChildren }
        guard isAnyError(typed) else { return .visitChildren }
        if isStdlibProtocolWitnessThrows(Syntax(node)) {
            return .visitChildren
        }
        if isInsideRequireMacroFunction(Syntax(node)) {
            return .visitChildren
        }
        let location = converter.location(for: typed.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "existential throws",
                message: throwsExistentialMessage
            )
        )
        return .visitChildren
    }

    private func isInsideRequireMacroFunction(_ node: Syntax) -> Swift::Bool {
        var current: Syntax? = node.parent
        while let candidate = current {
            if let fn = candidate.as(FunctionDeclSyntax.self) {
                return throwsBodyContainsRequireMacro(fn.body)
            }
            if let initDecl = candidate.as(InitializerDeclSyntax.self) {
                return throwsBodyContainsRequireMacro(initDecl.body)
            }
            if let accessor = candidate.as(AccessorDeclSyntax.self) {
                return throwsBodyContainsRequireMacro(accessor.body)
            }
            if candidate.is(StructDeclSyntax.self)
                || candidate.is(ClassDeclSyntax.self)
                || candidate.is(EnumDeclSyntax.self)
                || candidate.is(ActorDeclSyntax.self)
                || candidate.is(ExtensionDeclSyntax.self)
            {
                return false
            }
            current = candidate.parent
        }
        return false
    }

    private func throwsBodyContainsRequireMacro(_ body: CodeBlockSyntax?) -> Swift::Bool {
        guard let body else { return false }
        let finder = ThrowsExistentialRequireMacroFinder(viewMode: .sourceAccurate)
        finder.walk(body)
        return finder.found
    }

    private func isStdlibProtocolWitnessThrows(_ node: Syntax) -> Swift::Bool {
        var current: Syntax? = node.parent
        var witnessKey: Swift::String?
        var witnessSignature: FunctionSignatureSyntax?
        var inheritedTypeSuffixes: Swift::Set<Swift::String> = []
        while let candidate = current {
            if witnessKey == nil {
                if let fn = candidate.as(FunctionDeclSyntax.self) {
                    witnessKey = throwsWitnessKey(
                        name: fn.name.text,
                        parameterClause: fn.signature.parameterClause
                    )
                    witnessSignature = fn.signature
                } else if let initDecl = candidate.as(InitializerDeclSyntax.self) {
                    witnessKey = throwsWitnessKey(
                        name: "init",
                        parameterClause: initDecl.signature.parameterClause
                    )
                    witnessSignature = initDecl.signature
                }
            }
            if let clause = throwsInheritanceClause(of: candidate) {
                for inherited in clause.inheritedTypes {
                    inheritedTypeSuffixes.insert(throwsLastNameComponent(inherited.type))
                }
            }
            current = candidate.parent
        }
        guard let key = witnessKey, let signature = witnessSignature else { return false }
        guard
            node.position >= signature.position,
            node.endPosition <= signature.endPosition
        else { return false }
        guard let entry = throwsExistentialStdlibProtocolWitnessCitations[key] else { return false }
        for protocolName in entry.protocols where inheritedTypeSuffixes.contains(protocolName) {
            return true
        }
        switch key {
        case "init(from:)":
            return throwsIsCanonicalWitnessSignature(
                protocolSuffix: "Decodable",
                parameters: signature.parameterClause.parameters
            )

        case "encode(to:)":
            return throwsIsCanonicalWitnessSignature(
                protocolSuffix: "Encodable",
                parameters: signature.parameterClause.parameters
            )

        default:
            return false
        }
    }

    private func throwsWitnessKey(
        name: Swift::String,
        parameterClause: FunctionParameterClauseSyntax
    )
        -> Swift::String
    {
        var key = name + "("
        for parameter in parameterClause.parameters {
            key += parameter.firstName.text + ":"
        }
        key += ")"
        return key
    }

    private func isAnyError(_ type: TypeSyntax) -> Swift::Bool {
        guard let some = type.as(SomeOrAnyTypeSyntax.self),
            some.someOrAnySpecifier.tokenKind == .keyword(.any)
        else { return false }
        return isErrorType(some.constraint)
    }

    private func isErrorType(_ type: TypeSyntax) -> Swift::Bool {
        if let identifier = type.as(IdentifierTypeSyntax.self),
            identifier.name.text == "Error"
        {
            return true
        }
        if let member = type.as(MemberTypeSyntax.self),
            member.name.text == "Error",
            let base = member.baseType.as(IdentifierTypeSyntax.self),
            base.name.text == "Swift"
        {
            return true
        }
        return false
    }
}
