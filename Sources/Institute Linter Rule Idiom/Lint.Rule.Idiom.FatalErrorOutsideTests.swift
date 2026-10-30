public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `fatal error outside tests` = Lint.Rule(
        id: "fatal error outside tests",
        default: .warning,
        controls: [
            .init(
                id: "fatal error outside tests source",
                source: "func f() -> Never { fatalError(\"unreachable\") }",
                path: "Sources/Idiom Consumer/Trap.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests qualified",
                source: "func f() -> Never { Swift.fatalError() }",
                path: "Sources/Idiom Consumer/Trap.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests test",
                source: "func f() -> Never { fatalError(\"unreachable\") }",
                path: "Tests/Idiom Consumer Tests/Trap.swift",
                expectation: .clean
            ),
            .init(
                id: "fatal error outside tests parsing leaf witness",
                source: "struct Leaf: Parsing { var body: Never { fatalError(\"leaf\") } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests qualified generic coding leaf witness",
                source: "extension Example { struct Coder: Library.Utility.Coding<Int, Failure> { var body: Never { borrowing get { return fatalError(\"leaf\") } } } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests same-file conforming extension",
                source: "struct Leaf {}\nextension Leaf: Serializing { var body: Swift.Never { get { fatalError() } } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests declaration conformance with extension witness",
                source: "struct Leaf: Parsing {}\nextension Leaf { var body: Never { fatalError() } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests qualified extension conformance with extension witness",
                source: "enum A { struct Leaf {} }\nextension A.Leaf: Parsing {}\nextension A.Leaf { var body: Never { fatalError() } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests same name in another namespace",
                source: "enum A { struct Leaf {} }\nenum B { struct Leaf {} }\nextension A.Leaf: Parsing {}\nextension B.Leaf { var body: Never { fatalError() } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests top-level same name",
                source: "enum A { struct Leaf {} }\nextension A.Leaf: Parsing {}\nstruct Leaf { var body: Never { fatalError() } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests nested conformer same name",
                source: "enum A { struct Leaf: Parsing {} }\nextension Leaf { var body: Never { fatalError() } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests nonconforming never body",
                source: "struct Leaf { var body: Never { fatalError() } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests leaf body of another type",
                source: "struct Leaf: Parsing { var body: Int { fatalError() } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests leaf never property not named body",
                source: "struct Leaf: Parsing { var other: Never { fatalError() } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests leaf never body with more statements",
                source: "struct Leaf: Parsing { var body: Never { log(); fatalError() } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests leaf protocol default",
                source: "extension Parsing where Self: ~Copyable, Body == Never { public var body: Never { borrowing get { fatalError(\"leaf\") } } }",
                path: "Sources/Idiom Consumer/Parsing.swift",
                expectation: .clean
            ),
            .init(
                id: "fatal error outside tests module-qualified leaf protocol default",
                source: "extension Coder::Coding where Body == Swift.Never { var body: Never { fatalError() } }",
                path: "Sources/Idiom Consumer/Coding.swift",
                expectation: .clean
            ),
            .init(
                id: "fatal error outside tests protocol default without Never body constraint",
                source: "extension Parsing { var body: Never { fatalError() } }",
                path: "Sources/Idiom Consumer/Parsing.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests Never body default of another protocol",
                source: "extension Rendering where Body == Never { var body: Never { fatalError() } }",
                path: "Sources/Idiom Consumer/Rendering.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests member",
                source: "func f() { logger.fatalError(\"message\") }",
                path: "Sources/Idiom Consumer/Log.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let path = source.file.filePath
            guard path.hasPrefix("Sources/") || path.contains("/Sources/") else {
                return []
            }
            let visitor = IdiomFatalErrorOutsideTestsVisitor(
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
internal let idiomFatalErrorOutsideTestsMessage: Swift::String =
    "[fatal error outside tests] [SOURCE-FATAL-ERROR]: `fatalError` traps the "
    + "process; library and executable sources model the failure as a typed "
    + "error or make the state unrepresentable. `fatalError` is admitted only "
    + "in tests and fixtures."

internal final class IdiomFatalErrorOutsideTestsVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

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

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let isFatalError: Swift::Bool =
            if let reference = node.calledExpression.as(DeclReferenceExprSyntax.self) {
                reference.baseName.text == "fatalError"
            } else if let member = node.calledExpression.as(MemberAccessExprSyntax.self) {
                member.declName.baseName.text == "fatalError"
                    && member.base?.as(DeclReferenceExprSyntax.self)?.baseName.text == "Swift"
            } else {
                false
            }
        guard isFatalError, !isLeafProtocolDefaultBody(node) else { return .visitChildren }
        let location = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "fatal error outside tests",
                message: idiomFatalErrorOutsideTestsMessage
            )
        )
        return .visitChildren
    }

    private func isLeafProtocolDefaultBody(_ node: FunctionCallExprSyntax) -> Swift::Bool {
        let statement: Syntax? =
            if let returned = node.parent?.as(ReturnStmtSyntax.self) {
                Syntax(returned)
            } else {
                Syntax(node)
            }
        guard let item = statement?.parent?.as(CodeBlockItemSyntax.self),
            let items = item.parent?.as(CodeBlockItemListSyntax.self),
            items.count == 1
        else { return false }
        let block: AccessorBlockSyntax? =
            if let block = items.parent?.as(AccessorBlockSyntax.self) {
                block
            } else if let body = items.parent?.as(CodeBlockSyntax.self),
                let accessor = body.parent?.as(AccessorDeclSyntax.self),
                accessor.accessorSpecifier.tokenKind == .keyword(.get),
                let list = accessor.parent?.as(AccessorDeclListSyntax.self),
                list.count == 1
            {
                list.parent?.as(AccessorBlockSyntax.self)
            } else {
                nil
            }
        guard let binding = block?.parent?.as(PatternBindingSyntax.self),
            binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "body",
            let type = binding.typeAnnotation?.type,
            idiomIsNever(type)
        else { return false }
        return idiomIsLeafProtocolNeverDefault(enclosing: Syntax(binding))
    }
}

internal let idiomLeafProtocols: Swift::Set<Swift::String> = ["Parsing", "Serializing", "Coding"]

internal func idiomLastTypeName(_ type: TypeSyntax) -> Swift::String? {
    if let member = type.as(MemberTypeSyntax.self) {
        member.name.text
    } else if let identifier = type.as(IdentifierTypeSyntax.self) {
        identifier.name.text
    } else {
        nil
    }
}

internal func idiomIsNever(_ type: TypeSyntax) -> Swift::Bool {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        identifier.name.text == "Never"
            && (identifier.moduleSelector.map { $0.moduleName.text == "Swift" } ?? true)
    } else if let member = type.as(MemberTypeSyntax.self) {
        member.name.text == "Never"
            && member.baseType.as(IdentifierTypeSyntax.self)?.name.text == "Swift"
    } else {
        false
    }
}

internal func idiomIsLeafProtocolNeverDefault(enclosing node: Syntax) -> Swift::Bool {
    var current = node.parent
    while let candidate = current {
        if let extensionDecl = candidate.as(ExtensionDeclSyntax.self) {
            guard let name = idiomLastTypeName(extensionDecl.extendedType), idiomLeafProtocols.contains(name) else {
                return false
            }
            return extensionDecl.genericWhereClause?.requirements.contains { element in
                guard let sameType = element.requirement.as(SameTypeRequirementSyntax.self),
                    let left = sameType.leftType.as(TypeSyntax.self),
                    let right = sameType.rightType.as(TypeSyntax.self)
                else { return false }
                return idiomLastTypeName(left) == "Body" && idiomIsNever(right)
            } ?? false
        }
        if candidate.is(StructDeclSyntax.self) || candidate.is(EnumDeclSyntax.self)
            || candidate.is(ClassDeclSyntax.self) || candidate.is(ActorDeclSyntax.self)
            || candidate.is(ProtocolDeclSyntax.self)
        {
            return false
        }
        current = candidate.parent
    }
    return false
}
