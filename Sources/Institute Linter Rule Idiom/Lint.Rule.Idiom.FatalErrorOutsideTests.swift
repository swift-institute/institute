public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    /// A `* Test Support` target exists only for tests, so its sources aren't checked. A `fatalError` that is the only
    /// statement of the body of a function returning `Never`, or of a computed property or subscript of type `Never`,
    /// isn't counted: the type already says the body never returns (swift-institute/Issues#271).
    public static let `fatal error outside tests` = Lint.Rule(
        id: "fatal error outside tests",
        default: .warning,
        suppression: .next,
        controls: [
            .init(
                id: "fatal error outside tests source",
                source: "func f() { fatalError(\"unreachable\") }",
                path: "Sources/Idiom Consumer/Trap.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests qualified",
                source: "func f() { Swift.fatalError() }",
                path: "Sources/Idiom Consumer/Trap.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests test",
                source: "func f() { fatalError(\"unreachable\") }",
                path: "Tests/Idiom Consumer Tests/Trap.swift",
                expectation: .clean
            ),
            .init(
                id: "fatal error outside tests Never function body",
                source: "func f() -> Never { fatalError(\"unreachable\") }",
                path: "Sources/Idiom Consumer/Trap.swift",
                expectation: .clean
            ),
            .init(
                id: "fatal error outside tests returned in a Swift Never function",
                source: "func f() -> Swift.Never { return Swift.fatalError() }",
                path: "Sources/Idiom Consumer/Trap.swift",
                expectation: .clean
            ),
            .init(
                id: "fatal error outside tests Never property body",
                source: "struct Leaf: Parsing { var body: Never { fatalError(\"leaf\") } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .clean
            ),
            .init(
                id: "fatal error outside tests Never borrowing getter",
                source: "extension Example { struct Coder: Library.Utility.Coding<Int, Failure> { var body: Never { borrowing get { return fatalError(\"leaf\") } } } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .clean
            ),
            .init(
                id: "fatal error outside tests Never subscript body",
                source: "struct S { subscript(index: Int) -> Never { fatalError() } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .clean
            ),
            .init(
                id: "fatal error outside tests leaf protocol default",
                source: "extension Parsing where Self: ~Copyable, Body == Never { public var body: Never { borrowing get { fatalError(\"leaf\") } } }",
                path: "Sources/Idiom Consumer/Parsing.swift",
                expectation: .clean
            ),
            .init(
                id: "fatal error outside tests Never function with more statements",
                source: "func f() -> Never { log(); fatalError() }",
                path: "Sources/Idiom Consumer/Trap.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests Never property with more statements",
                source: "struct Leaf: Parsing { var body: Never { log(); fatalError() } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests branch in a Never function",
                source: "func f(_ c: Bool) -> Never { if c { fatalError(\"a\") } else { fatalError(\"b\") } }",
                path: "Sources/Idiom Consumer/Trap.swift",
                expectation: .findings(2)
            ),
            .init(
                id: "fatal error outside tests closure in a Never function",
                source: "func f() -> Never { run { fatalError() } }",
                path: "Sources/Idiom Consumer/Trap.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests body of another type",
                source: "struct Leaf: Parsing { var body: Int { fatalError() } }",
                path: "Sources/Idiom Consumer/Leaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests optional Never function",
                source: "func f() -> Never? { fatalError() }",
                path: "Sources/Idiom Consumer/Trap.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests Never closure",
                source: "let trap: () -> Never = { fatalError() }",
                path: "Sources/Idiom Consumer/Trap.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "fatal error outside tests unavailable declaration",
                source: "struct S { @available(*, unavailable) init() { fatalError() } }",
                path: "Sources/Idiom Consumer/Unavailable.swift",
                expectation: .clean
            ),
            .init(
                id: "fatal error outside tests test support target",
                source: "func f() { fatalError() }",
                path: "Sources/Idiom Test Support/Trap.swift",
                expectation: .clean
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
            if path.split(separator: "/").contains(where: { $0.hasSuffix("Test Support") }) {
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

    /// `@available(*, unavailable)` declarations can never be called; their
    /// body exists only to satisfy the compiler.
    private func isInsideUnavailableDecl(_ node: Syntax) -> Swift::Bool {
        var current = node.parent
        while let candidate = current {
            if let attributes = candidate.asProtocol((any WithAttributesSyntax).self)?.attributes {
                for element in attributes {
                    guard case .attribute(let attribute) = element,
                        attribute.attributeName.trimmedDescription == "available",
                        let arguments = attribute.arguments
                    else { continue }
                    if arguments.tokens(viewMode: .sourceAccurate).contains(where: {
                        $0.tokenKind == .keyword(.unavailable) || $0.text == "unavailable"
                    }) {
                        return true
                    }
                }
            }
            current = candidate.parent
        }
        return false
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
        guard isFatalError, !isSoleStatementOfNeverBody(node), !isInsideUnavailableDecl(Syntax(node))
        else { return .visitChildren }
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

    /// swift-institute/Issues#271: the call, or a `return` of it, is the only statement of the body of a function
    /// returning `Never`, or of the getter of a computed property or subscript of type `Never`. The type already
    /// says the body never returns, and the call is all the body does.
    private func isSoleStatementOfNeverBody(_ node: FunctionCallExprSyntax) -> Swift::Bool {
        let statement: Syntax =
            if let returned = node.parent?.as(ReturnStmtSyntax.self) {
                Syntax(returned)
            } else {
                Syntax(node)
            }
        guard let item = statement.parent?.as(CodeBlockItemSyntax.self),
            let items = item.parent?.as(CodeBlockItemListSyntax.self),
            items.count == 1,
            let container = items.parent
        else { return false }
        if let block = container.as(AccessorBlockSyntax.self) {
            return idiomIsNeverTyped(block)
        }
        guard let body = container.as(CodeBlockSyntax.self) else { return false }
        if let function = body.parent?.as(FunctionDeclSyntax.self) {
            return function.signature.returnClause.map { idiomIsNever($0.type) } ?? false
        }
        guard let accessor = body.parent?.as(AccessorDeclSyntax.self),
            accessor.accessorSpecifier.tokenKind == .keyword(.get),
            let block = accessor.parent?.as(AccessorDeclListSyntax.self)?.parent?.as(AccessorBlockSyntax.self)
        else { return false }
        return idiomIsNeverTyped(block)
    }
}

/// The accessor block is that of a computed property or subscript of type `Never`.
internal func idiomIsNeverTyped(_ block: AccessorBlockSyntax) -> Swift::Bool {
    if let binding = block.parent?.as(PatternBindingSyntax.self) {
        return binding.typeAnnotation.map { idiomIsNever($0.type) } ?? false
    }
    if let subscriptDecl = block.parent?.as(SubscriptDeclSyntax.self) {
        return idiomIsNever(subscriptDecl.returnClause.type)
    }
    return false
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
