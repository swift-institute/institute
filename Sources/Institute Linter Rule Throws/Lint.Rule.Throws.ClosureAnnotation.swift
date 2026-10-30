public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `closure typed throws annotation` = Lint.Rule(
        id: "closure typed throws annotation",
        default: .warning,
        controls: [
            .init(
                id: "closure typed throws annotation inferred closure",
                source: "func read<E: Swift.Error>(_ values: [Int]) throws(E) { "
                    + "_ = values.map { try load($0) } }",
                path: "Sources/Throws Consumer/InferredThrowingClosure.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "closure typed throws annotation explicit closure",
                source: "func read<E: Swift.Error>(_ values: [Int]) throws(E) { "
                    + "_ = values.map { (value: Int) throws(E) -> Int in "
                    + "try load(value) } }",
                path: "Sources/Throws Consumer/TypedThrowingClosure.swift",
                expectation: .clean
            ),
            .init(
                id: "closure typed throws annotation expect throws boundary",
                source: "func read() throws(Read.Error) { "
                    + "#expect(throws: Read.Error.self) { try load() } }",
                path: "Sources/Throws Consumer/ExpectThrows.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ThrowsClosureAnnotationVisitor(
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
internal let throwsClosureAnnotationMessage: Swift::String =
    "[closure typed throws annotation] [API-ERR-004]: closure inside a "
    + "`throws(E)` context contains `try` but lacks an explicit "
    + "`throws(E)` annotation — Swift 6.2 infers `any Error` and erases "
    + "the typed throw."

internal func throwsIsTypedThrows(_ clause: ThrowsClauseSyntax?) -> Swift::Bool {
    guard let clause else { return false }
    return clause.type != nil
}

internal func throwsClosureIsInsideExpectThrows(_ node: ClosureExprSyntax) -> Swift::Bool {
    guard let parent = node.parent else { return false }
    guard let macro = parent.as(MacroExpansionExprSyntax.self) else { return false }
    guard macro.macroName.text == "expect" else { return false }
    for argument in macro.arguments {
        if argument.label?.text == "throws" {
            return true
        }
    }
    return false
}

internal func throwsClosureTryIsInsideMaterializingDoCatch(_ node: Syntax) -> Swift::Bool {
    var current: Syntax? = node.parent
    while let candidate = current {
        if let doStmt = candidate.as(DoStmtSyntax.self) {
            if !doStmt.catchClauses.isEmpty,
                doStmt.catchClauses.contains(where: throwsClosureCatchIsCatchAll),
                doStmt.catchClauses.allSatisfy(throwsClosureCatchIsNonPropagating)
            {
                return true
            }
        }
        if candidate.is(ClosureExprSyntax.self) { return false }
        current = candidate.parent
    }
    return false
}

internal func throwsClosureCatchIsCatchAll(_ clause: CatchClauseSyntax) -> Swift::Bool {
    clause.catchItems.isEmpty
        || clause.catchItems.allSatisfy { $0.pattern == nil && $0.whereClause == nil }
}

internal func throwsClosureCatchIsNonPropagating(_ clause: CatchClauseSyntax) -> Swift::Bool {
    let finder = ThrowsClosureCatchPropagationFinder(viewMode: .sourceAccurate)
    finder.walk(clause.body)
    return !finder.foundPropagation
}

internal final class ThrowsClosureAnnotationVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var typedThrowsDepth: Swift::Int = 0

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
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
                identifier: "closure typed throws annotation",
                message: throwsClosureAnnotationMessage
            )
        )
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if throwsIsTypedThrows(node.signature.effectSpecifiers?.throwsClause) {
            typedThrowsDepth += 1
        }
        return .visitChildren
    }
    override func visitPost(_ node: FunctionDeclSyntax) {
        if throwsIsTypedThrows(node.signature.effectSpecifiers?.throwsClause) {
            typedThrowsDepth -= 1
        }
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        if throwsIsTypedThrows(node.signature.effectSpecifiers?.throwsClause) {
            typedThrowsDepth += 1
        }
        return .visitChildren
    }
    override func visitPost(_ node: InitializerDeclSyntax) {
        if throwsIsTypedThrows(node.signature.effectSpecifiers?.throwsClause) {
            typedThrowsDepth -= 1
        }
    }

    override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        if throwsIsTypedThrows(node.effectSpecifiers?.throwsClause) {
            typedThrowsDepth += 1
        }
        return .visitChildren
    }
    override func visitPost(_ node: AccessorDeclSyntax) {
        if throwsIsTypedThrows(node.effectSpecifiers?.throwsClause) {
            typedThrowsDepth -= 1
        }
    }

    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        let isTyped = throwsIsTypedThrows(node.signature?.effectSpecifiers?.throwsClause)
        let wasInTypedContext = typedThrowsDepth > 0
        if isTyped { typedThrowsDepth += 1 }
        guard wasInTypedContext, !isTyped else { return .visitChildren }
        if throwsClosureIsInsideExpectThrows(node) {
            return .visitChildren
        }
        let finder = ThrowsClosureTryFinder(viewMode: .sourceAccurate)
        for statement in node.statements {
            finder.walk(statement)
            if finder.found { break }
        }
        guard finder.found else { return .visitChildren }
        let position: AbsolutePosition =
            if let signature = node.signature {
                signature.positionAfterSkippingLeadingTrivia
            } else {
                node.leftBrace.positionAfterSkippingLeadingTrivia
            }
        emit(at: position)
        return .visitChildren
    }
    override func visitPost(_ node: ClosureExprSyntax) {
        if throwsIsTypedThrows(node.signature?.effectSpecifiers?.throwsClause) {
            typedThrowsDepth -= 1
        }
    }
}
